#!/bin/bash

# Copyright 2022 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

export PROJECT_ID=$(gcloud config get project)
export REGION=${REGION:=us-central1} # default us-central1 region if not defined

JOB_NAME=parallel-job
NUM_TASKS=10

IMAGE_NAME=gcr.io/${PROJECT_ID}/${JOB_NAME}

INPUT_FILE=input_file.txt
INPUT_BUCKET=gs://input-${PROJECT_ID}
INPUT_OBJECT=${INPUT_BUCKET}/${INPUT_FILE}

echo "Configure gcloud to use $REGION for Cloud Run"
gcloud config set run/region ${REGION}

echo "Enabling required services"
gcloud services enable \
    run.googleapis.com \
    cloudbuild.googleapis.com

echo "Build sample into a container"
gcloud builds submit --pack image=$IMAGE_NAME

echo "Creating input bucket $INPUT_BUCKET and generating random data."
gsutil mb $INPUT_BUCKET
base64 /dev/urandom | head -c 100000 >${INPUT_FILE}
gsutil cp $INPUT_FILE $INPUT_OBJECT

# Delete job if it already exists.
gcloud beta run jobs delete ${JOB_NAME} --quiet

echo "Creating ${JOB_NAME} using $IMAGE_NAME, $INPUT_OBJECT, in ${NUM_TASKS} tasks"
gcloud beta run jobs create ${JOB_NAME} --execute-now \
    --image $IMAGE_NAME \
    --command python \
    --args process.py,$INPUT_FILE \
    --tasks $NUM_TASKS
