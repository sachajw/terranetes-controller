#!/usr/bin/env bats
#
# Copyright 2021 Appvia Ltd <info@appvia.io>
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

load test/e2e/lib/helper.bash

setup() {
  [[ ! -f ${BATS_PARENT_TMPNAME}.skip ]] || skip "skip remaining tests"
}

teardown() {
  [[ -n "$BATS_TEST_COMPLETED" ]] || touch ${BATS_PARENT_TMPNAME}.skip
}

@test "We should be able to approve the terraform configuration" {
  runit "kubectl -n ${APP_NAMESPACE} annotate configurations.terraform.appvia.io bucket \"terraform.appvia.io/apply\"=true --overwrite"
  [[ "$status" -eq 0 ]]
}

@test "We should have a job created in the terraform-system ready to run " {
  labels="terraform.appvia.io/configuration=bucket,terraform.appvia.io/stage=apply"

  retry 10 "kubectl -n ${NAMESPACE} get job -l ${labels} -o json" "jq -r '.items[0].status.conditions[0].type' | grep -q Complete"
  [[ "$status" -eq 0 ]]
  runit "kubectl -n ${NAMESPACE} get job -l ${labels} -o json" "jq -r '.items[0].status.conditions[0].status' | grep -q True"
  [[ "$status" -eq 0 ]]
}

@test "We should have a job created in the application namespace ready to watch apply" {
  labels="terraform.appvia.io/configuration=bucket,terraform.appvia.io/stage=apply"

  runit "kubectl -n ${APP_NAMESPACE} get job -l ${labels} -o json" "jq -r '.items[0].status.conditions[0].type' | grep -q Complete"
  [[ "$status" -eq 0 ]]
  runit "kubectl -n ${APP_NAMESPACE} get job -l ${labels} -o json" "jq -r '.items[0].status.conditions[0].status' | grep -q True"
  [[ "$status" -eq 0 ]]
}

@test "We should have a configuration sucessfully applied" {
  runit "kubectl -n ${APP_NAMESPACE} get configuration bucket -o json" "jq -r '.status.conditions[2].name' | grep -q 'Terraform Apply'"
  [[ "$status" -eq 0 ]]
  runit "kubectl -n ${APP_NAMESPACE} get configuration bucket -o json" "jq -r '.status.conditions[2].reason' | grep -q 'Ready'"
  [[ "$status" -eq 0 ]]
  runit "kubectl -n ${APP_NAMESPACE} get configuration bucket -o json" "jq -r '.status.conditions[2].status' | grep -q 'True'"
  [[ "$status" -eq 0 ]]
  runit "kubectl -n ${APP_NAMESPACE} get configuration bucket -o json" "jq -r '.status.conditions[2].type' | grep -q 'TerraformApply'"
  [[ "$status" -eq 0 ]]
}

@test "We should have resources indicated in the status" {
  runit "kubectl -n ${APP_NAMESPACE} get configuration bucket -o json" "jq -r '.status.resources' | grep -q '5'"
  [[ "$status" -eq 0 ]]
}

@test "We should have a secret in the application namespace" {
  runit "kubectl -n ${APP_NAMESPACE} get secret test"
  [[ "$status" -eq 0 ]]
}