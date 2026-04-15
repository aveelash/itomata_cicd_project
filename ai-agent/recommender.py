def recommend_action(pod_phase, containers, issues, warning_events):
    """
    Decide what action to recommend for a pod.
    Main rule:
    - Current live pod state is more important than old warning history.
    """

    # ----------------------------
    # 1. Check current container health first
    # ----------------------------
    has_not_ready = False
    has_restarts = False
    has_crash_loop = False
    has_image_pull = False
    has_terminated_error = False

    for container in containers:
        if not container["ready"]:
            has_not_ready = True

        if container["restart_count"] > 0:
            has_restarts = True

        if container["waiting_reason"] == "CrashLoopBackOff":
            has_crash_loop = True

        if container["waiting_reason"] == "ImagePullBackOff":
            has_image_pull = True

        if container["terminated_reason"] == "Error" or container["last_terminated_reason"] == "Error":
            has_terminated_error = True

    # Hard failures first
    if pod_phase == "Failed":
        return (
            "pod_failed",
            "high",
            "restart_pod",
            "Pod phase is Failed"
        )

    if has_crash_loop:
        return (
            "crash_loop",
            "high",
            "restart_pod",
            "Container is in CrashLoopBackOff"
        )

    if has_image_pull:
        return (
            "image_pull_error",
            "high",
            "alert_human_or_check_registry_network",
            "Container image cannot be pulled"
        )

    if has_terminated_error and has_not_ready:
        return (
            "container_terminated_error",
            "high",
            "restart_pod",
            "Container terminated with Error and is not ready"
        )

    if pod_phase == "Pending":
        # Only check scheduling/capacity here when pod is currently pending
        for warning in warning_events:
            if "FailedScheduling" in warning and "Too many pods" in warning:
                return (
                    "cluster_capacity_issue",
                    "high",
                    "do_not_delete_alert_human",
                    "Node is full and cannot schedule more pods"
                )

            if "FailedScheduling" in warning:
                return (
                    "scheduling_issue",
                    "high",
                    "do_not_delete_alert_human",
                    "Pod has scheduling problems"
                )

        return (
            "pod_pending",
            "medium",
            "monitor_only",
            "Pod is pending"
        )

    if pod_phase != "Running":
        return (
            "pod_not_running",
            "high",
            "monitor_only",
            f"Pod phase is {pod_phase}"
        )

    if has_not_ready:
        return (
            "container_not_ready",
            "medium",
            "monitor_only",
            "Container is not ready yet"
        )

    if has_restarts:
        return (
            "container_restarted",
            "medium",
            "inspect_and_monitor",
            "Container has restarted before, but is currently running"
        )

    # ----------------------------
    # 2. If pod is healthy now, ignore stale old warning events
    # ----------------------------
    all_ready = True
    for container in containers:
        if not container["ready"]:
            all_ready = False
            break

    if pod_phase == "Running" and all_ready:
        return (
            "healthy",
            "low",
            "no_action",
            "Pod is currently healthy"
        )

    # ----------------------------
    # 3. Fallback
    # ----------------------------
    if issues and issues != ["Healthy"]:
        return (
            "general_warning",
            "medium",
            "inspect_events_and_logs",
            "Pod has warning signals"
        )

    return (
        "healthy",
        "low",
        "no_action",
        "Pod is healthy"
    )
