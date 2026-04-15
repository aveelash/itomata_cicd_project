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

    if result["issue_type"] == "cluster_capacity_issue":
        print("\n[AI Alert]")
        print("Cluster capacity issue detected.")
        print("Suggested fixes:")
        print("1. Reduce replicas")
        print("2. Add more nodes")
        print("3. Use a bigger EC2 instance type")
        print("4. Check max pod limit on the node")

    elif result["issue_type"] == "network_ip_capacity_issue":
        print("\n[AI Alert]")
        print("AWS CNI / IP capacity issue detected.")
        print("Suggested fixes:")
        print("1. Check available IPs in subnet")
        print("2. Check aws-node pod health")
        print("3. Add node capacity")
        print("4. Reduce pod count")

    elif result["issue_type"] == "image_pull_issue_history":
        print("\n[AI Alert]")
        print("Image pull issue detected.")
        print("Suggested fixes:")
        print("1. Check image name and tag")
        print("2. Check ECR access")
        print("3. Check network connectivity")
        print("4. Check repository permissions")

    elif result["issue_type"] == "crash_loop":
        print("\n[AI Alert]")
        print("Crash loop detected.")
        print("Suggested fixes:")
        print("1. Check pod logs")
        print("2. Check environment variables")
        print("3. Check app startup errors")
        print("4. Restart pod if needed")

    elif result["issue_type"] == "container_restarted":
        print("\n[AI Alert]")
        print("Container restart detected.")
        print("Suggested fixes:")
        print("1. Check logs")
        print("2. Check last terminated reason")
        print("3. Monitor if restart happens again")
        print("4. Investigate app crash cause")

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
