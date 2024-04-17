#!/bin/bash

OVERLAY=$OVERLAY
SERVICE=$SERVICE
SERVICE_REPOSITORY_PATH=$SERVICE_REPOSITORY_PATH
VERSION=$(cd $SERVICE_REPOSITORY_PATH && git rev-parse --short HEAD)
IMG_URL=$REGISTRY_BASE_URL/$SERVICE:v-$VERSION
BRANCH=release/$SERVICE/$OVERLAY

scan_code_vulnerabilities() {
  echo "Scanning code vulnerabilities..."
}

build_container_image() {
  echo "Building container image..."
  echo "docker build -t $IMG_URL $SERVICE_REPOSITORY_PATH"
}

push_container_image() {
  echo "Pushing container image..."
  echo "docker push $IMG_URL"
}

update_overlay_image() {
  echo "Updating overlay image tag..."
  cd k8s/overlays/$OVERLAY && kustomize edit set image $SERVICE=$IMG_URL
  git config --global user.email 'worflow-bot@example.com'
  git config --global user.name 'Workflow Bot'
  git fetch
  git checkout -B $BRANCH
  git add kustomization.yaml
  git commit -m "Release $SERVICE in $OVERLAY ($VERSION)."
  git push origin $BRANCH
}

create_overlay_pull_request() {
  echo "Creating overlay pull request..."
  gh pr create -B main -H $BRANCH --title "Release \`$SERVICE\` in \`$OVERLAY\`" --body 'Created by Github Actions.'
}

auto_merge_overlay_pull_request() {
  echo "Auto-merging overlay pull request..."
}

action=${1//-/_}
$action ${@:2}
