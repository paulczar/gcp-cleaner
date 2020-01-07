#!/bin/bash

#set -eux

region=us-central1

FAIL=0

waitfor() {
  for job in `jobs -p`
  do
      wait $job || let "FAIL+=1"
  done
}

echo "--> Destroy VMs"
for i in a b c; do
    zone=$region-$i
    echo "====> $zone"
    gcloud compute instances list --format 'value(name)' --filter="zone:$zone" \
      | /usr/bin/parallel "gcloud compute instances delete --zone $zone --quiet {}" &
done
waitfor

echo "--> Destroy Disks"
for i in a b c; do
    zone=$region-$i
    echo "====> $zone"
    gcloud compute disks list --format "value(name)" --filter="zone:$zone and -users:*" \
      | /usr/bin/parallel "gcloud compute disks delete --zone $zone --quiet {}" &
done



echo "--> Destroy target proxies"
gcloud compute target-http-proxies list --format 'value(name)' \
  | parallel 'gcloud compute target-http-proxies delete --quiet {}' &

gcloud compute target-https-proxies list --format 'value(name)' \
  | parallel 'gcloud compute target-https-proxies delete --quiet {}' &

waitfor

echo "--> Destroy url maps"
gcloud compute url-maps list --format 'value(name)' \
  | parallel 'gcloud compute url-maps delete --quiet {}' &
waitfor

echo "--> Destroy backend services"
gcloud compute backend-services list --global --format 'value(name)' \
  | parallel 'gcloud compute backend-services delete --global --quiet {}' &

waitfor

echo "--> Destroy instance groups"
for i in a b c; do
    zone=$region-$i
  gcloud compute instance-groups unmanaged list --filter="zone:($zone)" --format 'value(name)' \
    | parallel "gcloud compute instance-groups unmanaged delete --quiet {} --zone $zone" &
done
waitfor

echo "--> Destroy firewall rules"
gcloud compute firewall-rules list --format 'value(name)' \
  | parallel 'gcloud compute firewall-rules delete --quiet {}' &

echo "--> Destroy forwarding rules"
gcloud compute forwarding-rules list --format 'value(name)' \
  | parallel "gcloud compute forwarding-rules delete --quiet \
  --region=${region} {}" &

gcloud compute forwarding-rules list --global --format 'value(name)' \
  | parallel "gcloud compute forwarding-rules delete --quiet \
  --global {}" &

echo "--> Destroy addresses"
gcloud compute addresses list --global --format 'value(name)' | \
  parallel 'gcloud compute addresses delete --global --quiet {}' &

gcloud compute addresses list --format 'value(name)' | \
  parallel 'gcloud compute addresses delete --quiet {}' &

echo "--> Destroy routes"
gcloud compute routes list --format 'value(name)' | \
  parallel 'gcloud compute routes delete --quiet {}' &

waitfor

echo "--> Destroy target pools"
gcloud compute target-pools list --format 'value(name)' \
  | parallel 'gcloud compute target-pools delete --quiet {}' &

waitfor

echo "--> Destroy subnets"
gcloud compute networks subnets list --format 'value(name)' \
  | parallel gcloud compute networks subnets delete --quiet {}

echo "--> Destroy networks"
gcloud compute networks list --format 'value(name)' \
  | parallel gcloud compute networks delete --quiet {}

echo "---------------------------------------"
echo "Finished with $FAIL failures"
echo "---------------------------------------"
