
# Creat GCP instance

echo "Creating Compute instances"
#gcloud compute instances create test --machine-type=f1-micro --zone=asia-east1-a --image-family cos-stable --image-project cos-cloud --metadata-from-file startup-script=docker-install.sh   
 --image-family cos-stable --image-project cos-cloud --metadata-from-file startup-script=docker-install.sh

gcloud compute instances create frontend --machine-type=f1-micro --zone=us-central1-a --network="vm-vpc" --subnet="vm-vpc"  --tags=ssh --shielded-secure-boot --shielded-vtpm --shielded-integrity-monitoring --image-family cos-stable --image-project cos-cloud  --metadata=startup-script=docker-install.sh

