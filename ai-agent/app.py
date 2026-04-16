import time
from dotenv import load_dotenv
from kubernetes import client
from kubernetes.client.rest import ApiException

from kube_config import load_kube_config
from analyzer import analyze_pod
from printer import print_pod_report
from llm_analyzer import get_llm_explanation

load_dotenv()

# Stores when a pod first became unhealthy
unhealthy_since = {}

# Stores recently fixed pods so we do not keep deleting them again and again
recent_fixes = {}

FIX_COOLDOWN_SECONDS = 180


def delete_pod(v1, pod):
    try:
        print(f"[Action] Deleting pod {pod.metadata.name}")
        v1.delete_namespaced_pod(
            name=pod.metadata.name,
            namespace=pod.metadata.namespace
        )
        recent_fixes[pod.metadata.name] = time.time()
    except Exception as e:
        print(f"Error deleting pod: {e}")


def is_in_cooldown(pod_name):
    if pod_name not in recent_fixes:
        return False

    return (time.time() - recent_fixes[pod_name]) < FIX_COOLDOWN_SECONDS


def check_pods():
    v1 = client.CoreV1Api()

    try:
        pods = v1.list_namespaced_pod(namespace="default")
        print("\nChecking pods...\n")

        for pod in pods.items:
            result = analyze_pod(v1, pod, unhealthy_since)
            print_pod_report(result)

            # Call ChatGPT only for unhealthy pods
            print("\n[LLM Diagnosis]")
            explanation = get_llm_explanation(result)
            print(explanation)
            print("-" * 50)

            pod_name = result["pod_name"]

            # Never delete AI agent itself
            if pod_name.startswith("itomata-ai-agent"):
                continue

            # Only delete if analyzer says delete_pod
            if result.get("recommendation") == "delete_pod":
                if is_in_cooldown(pod_name):
                    print(f"[Cooldown] Skipping {pod_name}, recently fixed.\n")
                else:
                    delete_pod(v1, pod)

    except ApiException as e:
        print(f"Error talking to Kubernetes API: {e}")


def main():
    load_kube_config()

    while True:
        check_pods()
        time.sleep(30)


if __name__ == "__main__":
    main()
