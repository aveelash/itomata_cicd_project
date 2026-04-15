from kubernetes import client, config
from kubernetes.client.rest import ApiException
import time


def load_kube_config():
    try:
        config.load_incluster_config()
        print("Loaded in-cluster Kubernetes config")
    except Exception:
        config.load_kube_config()
        print("Loaded local Kubernetes config")


def get_pod_events(v1, namespace, pod_name):
    events_output = []

    try:
        field_selector = f"involvedObject.name={pod_name},involvedObject.namespace={namespace}"
        events = v1.list_namespaced_event(
            namespace=namespace, field_selector=field_selector)

        for event in events.items:
            events_output.append({
                "reason": event.reason,
                "message": event.message,
                "type": event.type,
                "count": event.count,
            })

    except ApiException as e:
        print(f"Could not fetch events for pod {pod_name}: {e}")

    return events_output


def get_pod_logs(v1, namespace, pod_name, tail_lines=25):
    try:
        logs = v1.read_namespaced_pod_log(
            name=pod_name,
            namespace=namespace,
            tail_lines=tail_lines
        )
        return logs
    except ApiException as e:
        return f"Could not fetch logs: {e}"


def analyze_event_warnings(events):
    warnings = []

    for event in events:
        if event["type"] == "Warning":
            warnings.append(f"{event['reason']}: {event['message']}")

    return warnings


def recommend_action(pod_phase, containers, issues, warning_events):
    issue_type = "healthy"
    severity = "low"
    recommendation = "no_action"
    reason = "Pod is healthy"

    if pod_phase != "Running":
        issue_type = "pod_not_running"
        severity = "high"
        recommendation = "monitor_or_restart_pod"
        reason = f"Pod phase is {pod_phase}"
        return issue_type, severity, recommendation, reason

    for container in containers:
        if container["waiting_reason"] == "CrashLoopBackOff":
            return (
                "crash_loop",
                "high",
                "collect_logs_and_restart_once",
                "Container is in CrashLoopBackOff"
            )

        if container["waiting_reason"] == "ImagePullBackOff":
            return (
                "image_pull_error",
                "high",
                "alert_human_do_not_restart_loop",
                "Container image cannot be pulled"
            )

        if container["restart_count"] > 0:
            return (
                "container_restarts",
                "medium",
                "inspect_logs",
                f"Container restarted {container['restart_count']} times"
            )

        if not container["ready"]:
            return (
                "container_not_ready",
                "medium",
                "monitor_or_restart_pod",
                "Container is not ready"
            )

    for warning in warning_events:
        if "FailedScheduling" in warning:
            return (
                "cluster_capacity_issue",
                "medium",
                "check_cluster_capacity",
                "Pod had scheduling problems"
            )

        if "FailedCreatePodSandBox" in warning or "failed to assign an IP address" in warning:
            return (
                "network_ip_capacity_issue",
                "medium",
                "check_aws_cni_or_ip_capacity",
                "Pod had sandbox/IP assignment problems"
            )

    if issues and issues != ["Healthy"]:
        return (
            "general_warning",
            "medium",
            "inspect_events_and_logs",
            "Pod has warning signals"
        )

    return issue_type, severity, recommendation, reason


def analyze_pod(v1, pod):
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
                    f"Container {container.name} restarted {container.restart_count} times")

            if container_info["waiting_reason"]:
                issue_detected = True
                issues.append(
                    f"Container {container.name} waiting reason: {container_info['waiting_reason']}")

            if container_info["terminated_reason"]:
                issue_detected = True
                issues.append(
                    f"Container {container.name} terminated reason: {container_info['terminated_reason']}")

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


def print_pod_report(result):
    print("\n" + "=" * 60)
    print(f"Pod Name   : {result['pod_name']}")
    print(f"Namespace  : {result['namespace']}")
    print(f"Phase      : {result['phase']}")
    print(f"Node       : {result['node_name']}")
    print(f"Labels     : {result['labels']}")

    print("\nContainer Details:")
    for container in result["containers"]:
        print(f"  - Name                 : {container['name']}")
        print(f"    Image                : {container['image']}")
        print(f"    Ready                : {container['ready']}")
        print(f"    Restart Count        : {container['restart_count']}")
        print(f"    Waiting Reason       : {container['waiting_reason']}")
        print(f"    Terminated Reason    : {container['terminated_reason']}")
        print(
            f"    Last Terminated      : {container['last_terminated_reason']}")

    print("\nIssues:")
    for issue in result["issues"]:
        print(f"  - {issue}")

    print("\nRecommendation:")
    print(f"  - Issue Type     : {result['issue_type']}")
    print(f"  - Severity       : {result['severity']}")
    print(f"  - Action         : {result['recommendation']}")
    print(f"  - Reason         : {result['recommendation_reason']}")

    print("\nEvents:")
    if result["events"]:
        for event in result["events"]:
            print(
                f"  - Type: {event['type']}, Reason: {event['reason']}, Count: {event['count']}")
            print(f"    Message: {event['message']}")
    else:
        print("  - No related events found")

    print("\nRecent Logs:")
    if result["logs"]:
        print(result["logs"])
    else:
        print("No logs found")

    print("=" * 60)


def check_pods():
    v1 = client.CoreV1Api()

    try:
        pods = v1.list_namespaced_pod(namespace="default")
        print("\nChecking pods...\n")

        for pod in pods.items:
            result = analyze_pod(v1, pod)
            print_pod_report(result)

    except ApiException as e:
        print(f"Error talking to Kubernetes API: {e}")


def main():
    load_kube_config()

    while True:
        check_pods()
        time.sleep(30)


if __name__ == "__main__":
    main()
