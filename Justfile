PROJECT_NAME := "exampleproject"
PROJECT_ID   := "example-project-id"
SCHEDULE     := "0 8 * * *"
REGION       := "europe-west1"
TIMEZONE     := "Europe/Dublin"


# Install project and dev dependencies
dev:
	poetry install

# Install project without dev dependencies
install:
	poetry install --no-dev

# Deploy the cloud function to GCP
publish: _deploy_to_gfunctions 
	@echo "Published"

# Adds a message to the pubsub topic, using the content in misc/manual-payload.json
add_job:
	gcloud pubsub topics publish "projects/{{ PROJECT_ID }}/topics/trigger-{{ PROJECT_NAME }}" --message='$(shell cat misc/manual-payload.json)'

# Adds a Cloud Scheduler job to periodically run the job data collection (uses misc/scheduled-payload.json)
schedule_add:
	gcloud scheduler jobs create pubsub --project {{ PROJECT_ID }} {{ PROJECT_NAME }} \
		--schedule ${SCHEDULE} \
		--topic "trigger-{{ PROJECT_NAME }}" \
		--location {{ REGION }} \
		--time-zone "{{ TIMEZONE }}" \
		--message-body-from-file misc/scheduled-payload.json

# Updates an existing Cloud Scheduler job (uses misc/scheduled-payload.json)
schedule_update:
	gcloud scheduler jobs update pubsub --project {{ PROJECT_ID }} {{ PROJECT_NAME }} \
		--schedule ${SCHEDULE} \
		--topic "trigger-{{ PROJECT_NAME }}" \
		--message-body-from-file misc/scheduled-payload.json \
		--time-zone "{{ TIMEZONE }}" \
		--location {{ REGION }}


_ensure_poetry:
    @if [ "$(command -v poetry)" == "" ]; then \
        echo "\n\nPlease install poetry (e.g. pip install poetry)\n\n"; \
        exit 1; \
    fi

_create_pubsub_topic:
    ifeq ($(shell gcloud --project={{ PROJECT_ID }} pubsub topics list --filter="name~trigger-{{ PROJECT_NAME }}" | wc -l), 0)
        gcloud --project={{ PROJECT_ID }} pubsub topics create "trigger-{{ PROJECT_NAME }}"
    endif

_deploy_to_gfunctions: create_pubsub_topic export_conf
	gcloud functions deploy {{ PROJECT_NAME }} \
		--gen2 \
		--region {{ REGION }} \
		--project {{ PROJECT_ID }} \
		--runtime python39 \
		--memory 128Mi \
		--entry-point loadToBigQuery \
		--trigger-topic "trigger-{{ PROJECT_NAME }}" \
		--set-env-vars GOOGLE_CLOUD_PROJECT={{ PROJECT_ID }},TOPIC_NAME=trigger-{{ PROJECT_NAME }} \
		--set-secrets 'PROJECT_SECRET=project_secret_name:latest'\
		--timeout 60s \
		--max-instances 1