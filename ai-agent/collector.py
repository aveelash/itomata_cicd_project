from kubernetes.client.rest import ApiException


from datetime import datetime, timezone


def get_pod_events(v1, namespace, pod_name):
    try:
        events = v1.list_namespaced_event(namespace=namespace)

        pod_events = []

        # current time
        now = datetime.now(timezone.utc)

        for event in events.items:
            if event.involved_object.name == pod_name:

                # get event time safely
                event_time = None

                if event.last_timestamp:
                    event_time = event.last_timestamp
                elif event.event_time:
                    event_time = event.event_time
                elif event.first_timestamp:
                    event_time = event.first_timestamp

                # ❗ Skip if no timestamp
                if not event_time:
                    continue

                # 🔥 Calculate how old event is
                time_diff = (now - event_time).total_seconds()

                # ❗ Ignore old events (> 120 seconds)
                if time_diff > 120:
                    continue

                message = f"{event.reason}: {event.message}"

                if event.type == "Warning":
                    pod_events.append(message)

        return pod_events

    except Exception:
        return []


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
