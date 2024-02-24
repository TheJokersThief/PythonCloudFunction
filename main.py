import base64
import json
import functions_framework
import os
from datetime import datetime, timedelta
from cloudevents.http.event import CloudEvent

SECRET = os.getenv("PROJECT_SECRET")


@functions_framework.cloud_event
def loadToBigQuery(cloud_event: CloudEvent) -> None:
    hasEventData = False
    eventData = None
    if "message" in cloud_event.data and "data" in cloud_event.data["message"]:
        eventData = json.loads(base64.b64decode(cloud_event.data["message"]["data"]).decode())
        hasEventData = True

    if hasEventData:
        print(json.dumps(eventData))
