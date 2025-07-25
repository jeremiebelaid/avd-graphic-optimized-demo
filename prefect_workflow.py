import requests
from prefect import flow, task


@task
def get_data():
    """Fetches data from a sample API."""
    response = requests.get("https://jsonplaceholder.typicode.com/posts/1")
    response.raise_for_status()
    return response.json()


@task
def process_data(data):
    """Processes the data."""
    print("Processing data:")
    print(f"  Title: {data['title']}")
    print(f"  Body: {data['body']}")
    return {"processed": True, "title": data["title"]}


@flow
def simple_prefect_workflow():
    """A simple Prefect workflow to fetch and process data."""
    print("Starting the workflow...")
    data = get_data()
    result = process_data(data)
    print(f"Workflow finished with result: {result}") 