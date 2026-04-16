from datetime import datetime, timezone
from kubernetes.client.rest import ApiException


def get_pod_events(v1, namespace, pod_name):
    try:
        events = v1.list_namespaced_event(namespace=namespace)
        pod_events = []
        now = datetime.now(timezone.utc)

        for event in events.items:
            if event.involved_object.name != pod_name:
                continue

            event_time = None
            if event.last_timestamp:
                event_time = event.last_timestamp
            elif event.event_time:
                event_time = event.event_time
            elif event.first_timestamp:
                event_time = event.first_timestamp

            if not event_time:
                continue

            # Ignore old events older than 120 seconds
            time_diff = (now - event_time).total_seconds()
            if time_diff > 120:
                continue

            pod_events.append({
                "type": event.type,
                "reason": event.reason,
                "message": event.message,
                "count": event.count,
            })

        return pod_events

    except ApiException as e:
        print(f"Error getting pod events for {pod_name}: {e}")
        return []


def analyze_event_warnings(pod_events):
    warnings = []

    for event in pod_events:
        if isinstance(event, dict):
            if event.get("type") == "Warning":
                warnings.append(
                    f"{event.get('reason')}: {event.get('message')}")
        elif isinstance(event, str):
            warnings.append(event)

    return warnings


def get_pod_logs(v1, namespace, pod_name, tail_lines=25):
    try:
        logs = v1.read_namespaced_pod_log(
            name=pod_name,
            namespace=namespace,
            tail_lines=tail_lines
        )
        return logs if logs else "No logs found"
    except ApiException:
        return "No logs found"
