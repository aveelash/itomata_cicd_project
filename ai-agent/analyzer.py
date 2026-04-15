import time

from collector import get_pod_events, get_pod_logs, analyze_event_warnings
from recommender import recommend_action


def analyze_pod(v1, pod, unhealthy_since):
    pod_name = pod.metadata.name
    namespace = pod.metadata.namespace
    pod_phase = pod.status.phase
    node_name = pod.spec.node_name
    labels = pod.metadata.labels or {}

    issue_detected = False
    issues = []
    container_details = []

    if pod.status.container_statuses:
        for container in pod.status.container_statuses:
            container_info = {
                "name": container.name,
                "image": container.image,
                "ready": container.ready,
                "restart_count": container.restart_count,
                "waiting_reason": None,
                "terminated_reason": None,
                "last_terminated_reason": None,
            }

            if container.state.waiting:
                container_info["waiting_reason"] = container.state.waiting.reason

            if container.state.terminated:
                container_info["terminated_reason"] = container.state.terminated.reason

            if container.last_state and container.last_state.terminated:
                container_info["last_terminated_reason"] = container.last_state.terminated.reason

            if not container.ready:
                issue_detected = True
                issues.append(f"Container {container.name} is not ready")

            if container.restart_count > 0:
                issue_detected = True
                issues.append(
                    f"Container {container.name} restarted {container.restart_count} times"
                )

            if container_info["waiting_reason"]:
                issue_detected = True
                issues.append(
                    f"Container {container.name} waiting reason: {container_info['waiting_reason']}"
                )

            if container_info["terminated_reason"]:
                issue_detected = True
                issues.append(
                    f"Container {container.name} terminated reason: {container_info['terminated_reason']}"
                )

            if container_info["last_terminated_reason"]:
                issue_detected = True
                issues.append(
                    f"Container {container.name} last terminated reason: {container_info['last_terminated_reason']}"
                )

            container_details.append(container_info)

    if pod_phase != "Running":
        issue_detected = True
        issues.append(f"Pod phase is {pod_phase}")

    pod_events = get_pod_events(v1, namespace, pod_name)
    warning_events = analyze_event_warnings(pod_events)

    if warning_events:
        issue_detected = True
        for warning in warning_events:
            issues.append(f"Warning event: {warning}")

    pod_logs = get_pod_logs(v1, namespace, pod_name)

    issue_type, severity, recommendation, reason = recommend_action(
        pod_phase,
        container_details,
        issues if issues else ["Healthy"],
        warning_events
    )

    # -------------------------------
    # Extra smart logic for stuck pods
    # -------------------------------
    if issue_type == "container_not_ready":
        now = time.time()

        if pod_name not in unhealthy_since:
            unhealthy_since[pod_name] = now
            print(
                f"[Monitor] {pod_name} became not ready. Starting grace timer.")

        elapsed = now - unhealthy_since[pod_name]

        # If pod stays not ready for more than 30 seconds, recommend delete
        if elapsed > 30:
            issue_type = "container_not_ready"
            severity = "high"
            recommendation = "delete_pod"
            reason = "Pod stuck in not ready state for more than 30 seconds"

    else:
        # If pod becomes healthy again, remove from unhealthy tracking
        if pod_name in unhealthy_since:
            del unhealthy_since[pod_name]

    return {
        "pod_name": pod_name,
        "namespace": namespace,
        "phase": pod_phase,
        "node_name": node_name,
        "labels": labels,
        "issue_detected": issue_detected,
        "issues": issues if issues else ["Healthy"],
        "containers": container_details,
        "events": pod_events,
        "logs": pod_logs,
        "issue_type": issue_type,
        "severity": severity,
        "recommendation": recommendation,
        "recommendation_reason": reason,
    }
