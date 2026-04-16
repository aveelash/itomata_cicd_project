import os
from openai import OpenAI
from dotenv import load_dotenv

load_dotenv()


def get_llm_explanation(pod_result):
    api_key = os.getenv("OPENAI_API_KEY")
    model = os.getenv("OPENAI_MODEL", "gpt-4o-mini")

    if not api_key:
        return "LLM skipped: OPENAI_API_KEY not found."

    client = OpenAI(api_key=api_key)

    prompt = f"""
You are a Kubernetes DevOps expert.

Explain in VERY SIMPLE words:
1. What is the problem?
2. Why it happened?
3. How to fix it?

Pod Name: {pod_result.get('pod_name')}
Phase: {pod_result.get('phase')}
Issue Type: {pod_result.get('issue_type')}
Severity: {pod_result.get('severity')}

Issues:
{pod_result.get('issues')}

Logs:
{pod_result.get('logs')}
"""

    try:
        response = client.chat.completions.create(
            model=model,
            messages=[
                {"role": "system", "content": "You are a helpful Kubernetes troubleshooting assistant."},
                {"role": "user", "content": prompt}
            ],
            temperature=0.2
        )

        return response.choices[0].message.content

    except Exception as e:
        return f"LLM failed: {str(e)}"
