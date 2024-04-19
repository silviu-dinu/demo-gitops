#!/bin/bash

OVERLAY=$OVERLAY
SERVICE=$SERVICE
SERVICE_REPOSITORY_PATH=$SERVICE_REPOSITORY_PATH
VERSION=`git -C $SERVICE_REPOSITORY_PATH rev-parse --short HEAD 2> /dev/null`
IMG_URL=$REGISTRY_BASE_URL/$SERVICE:v-$VERSION
BRANCH=release/$SERVICE/$OVERLAY
OVARLAYS_JSON='["dev", "uat", "prod"]'

scan_code_vulnerabilities() {
  echo "Scanning code vulnerabilities..."
}

build_container_image() {
  echo "Building container image..."
  docker build -t $IMG_URL $SERVICE_REPOSITORY_PATH
}

push_container_image() {
  echo "Pushing container image..."
  echo $GH_TOKEN | docker login $REGISTRY_BASE_URL -u USERNAME --password-stdin
  docker push $IMG_URL
}

update_overlay_image() {
  echo "Updating overlay image tag..."

  local_branch=$BRANCH
  local_service=$SERVICE
  local_overlay=$OVERLAY
  local_img_url=$IMG_URL
  local_version=$VERSION

  local_overlay_base_path=k8s/overlays
  local_overlays_json=$OVARLAYS_JSON
  local_overlay_prev=`echo $local_overlays_json | jq -r '.[index("'$local_overlay'") - 1]'`
  local_overlay_is_first=`echo $local_overlays_json | jq -r 'index("'$local_overlay'") == 0'`

  # Check if this is the first overlay in the deployment chain
  if [[ $local_overlay_is_first == 'false' ]]; then
    local_version=`yq e '.images[] | select(.name == "'$local_service'") | .newTag' $local_overlay_base_path/$local_overlay_prev/kustomization.yaml`
    local_img_url=`yq e '.images[] | select(.name == "'$local_service'") | .newName + ":'$local_version'"' $local_overlay_base_path/$local_overlay/kustomization.yaml`
    echo "Copied image $local_img_url from $local_overlay_prev to $local_overlay overlay."
  fi

  # @TODO: move user details externally
  git config --global user.email 'worflow-bot@example.com'
  git config --global user.name 'Workflow Bot'

  git fetch
  git branch -r | grep $local_branch && git checkout $local_branch || git checkout -B $local_branch

  cd $local_overlay_base_path/$local_overlay && kustomize edit set image $local_service=$local_img_url

  # Exit if there are no changes
  [[ ! `git status --porcelain kustomization.yaml` ]] && exit 0

  git add kustomization.yaml
  git commit -m "Release $local_service in $local_overlay ($local_version)."
  git push origin $local_branch
}

create_overlay_pull_request() { # See https://stackoverflow.com/a/75308228
  echo "Creating overlay pull request..."
  existing_pr=$(gh pr list --head $BRANCH --json number --jq '.[].number')
  [[ $existing_pr ]] && echo "Pull request #$existing_pr exists." && exit 0
  gh pr create -B main -H $BRANCH --title "Release \`$SERVICE\` in \`$OVERLAY\`" --body 'Created by Github Actions.'
}

auto_merge_overlay_pull_request() {
  echo "Auto-merging overlay pull request..."
  GH_TOKEN=$GH_PAT gh pr merge $BRANCH --squash --auto

  # echo "Auto-merging DISABLED to allow triggering overlay-deploy."
  # gh pr merge $BRANCH --squash --auto
}

apply_overlays() {
  echo "Applying overlays..."
}

get_overlay_by_branch_name() {
  echo $1 | jq -Rr '. | split("/") | .[2]'
}

get_next_overlay_by_branch_name() {
  local_overlays_json=$OVARLAYS_JSON
  local_overlay=`get_overlay_by_branch_name $1`
  echo $local_overlays_json | jq -r '.[index("'$local_overlay'") + 1] + ""'
}

get_service_by_branch_name() {
  echo $1 | jq -Rr '. | split("/") | .[1]'
}

action=${1//-/_}
$action ${@:2}
