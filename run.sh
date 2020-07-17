#!/bin/bash
# Since we will work in the future with ISTIO, I found it correct to use their instructions to prepare the cluster
# They did a good job, we use their labor.
#


if ! [ -x "$(command -v kubectl)" ]; then
  echo "Installing kubectl..."
  curl -LO https://storage.googleapis.com/kubernetes-release/release/`curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt`/bin/linux/amd64/kubectl
  chmod +x ./kubectl
  sudo mv ./kubectl /usr/local/bin/kubectl
else
  echo "kubectl is already installed"
  
fi


if ! [ -x "$(command -v docker)" ]; then
  echo "Installing docker..."
  sudo apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    software-properties-common 
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
  sudo apt-key fingerprint 0EBFCD88
sudo add-apt-repository \
   "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
   $(lsb_release -cs) \
   stable"
  sudo apt-get update
  sudo apt-get install -y docker-ce
  sudo systemctl enable docker
  sudo groupadd docker
  sudo usermod -aG docker $USER
  echo "https://docs.docker.com/engine/install/linux-postinstall/"
  echo "Please reboot VM. This step need onli one time for run Docker as non root user"
  echo "If you not ready for reboot, simple type 'exit', script will be to continue, but docker now will be run as not root user"
  sudo newgrp docker
  echo "Done Docker" 
else
  echo "docker is already installed"
  docker -v
fi


if ! [ -x "$(command -v minikube)" ]; then
  echo "Installing minikube..."
  curl -Lo minikube https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
  chmod +x minikube
  sudo cp minikube /usr/local/bin/
else
  echo "minikube is already installed"
  sudo minikube version
fi

echo "Starting minikube..."
echo "Configuring minikube..."
minikube config set vm-driver docker
minikube start --memory=6384 --cpus=3
kubectl get pods

echo "Download and install Istio..."
curl -sL https://istio.io/downloadIstio | ISTIO_VERSION=1.6.4 sh -
cd istio*
export PATH="$PATH:$(pwd)/bin"
istioctl install --set profile=demo
echo "Adding a namespace label to instruct Istio to automatically inject Envoy sidecar proxies when you deploy your application later"
kubectl label namespace default istio-injection=enabled
echo "Print ISTIO status"
kubectl get --namespace=istio-system svc,deployment,pods,job,horizontalpodautoscaler,destinationrule
kubectl apply -f samples/bookinfo/platform/kube/bookinfo.yaml
kubectl get pods
echo "wait for start pods"
kubectl wait --for=condition=Ready pods --all --all-namespaces --timeout=300s
kubectl get pods
kubectl exec -it $(kubectl get pod -l app=ratings -o jsonpath='{.items[0].metadata.name}') -c ratings -- curl productpage:9080/productpage | grep -o "<title>.*</title>"
kubectl apply -f samples/bookinfo/networking/bookinfo-gateway.yaml
istioctl analyze
export INGRESS_PORT=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.spec.ports[?(@.name=="http2")].nodePort}')
export SECURE_INGRESS_PORT=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.spec.ports[?(@.name=="https")].nodePort}')
echo INGRESS_PORT: $INGRESS_PORT
echo SECURE_INGRESS_PORT: $SECURE_INGRESS_PORT
export INGRESS_HOST=$(minikube ip)
echo INGRESS_HOST: $INGRESS_HOST
export GATEWAY_URL=$INGRESS_HOST:$INGRESS_PORT
echo GATEWAY_URL: GATEWAY_URL
echo MAIN_SITE_URL: http://$GATEWAY_URL/productpage

export INGRESS_PORT=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.spec.ports[?(@.name=="http2")].nodePort}')
export SECURE_INGRESS_PORT=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.spec.ports[?(@.name=="https")].nodePort}')
echo INGRESS_PORT: $INGRESS_PORT
echo SECURE_INGRESS_PORT: $SECURE_INGRESS_PORT
export INGRESS_HOST=$(minikube ip)
echo INGRESS_HOST: $INGRESS_HOST
export GATEWAY_URL=$INGRESS_HOST:$INGRESS_PORT
echo GATEWAY_URL: GATEWAY_URL
echo MAIN_SITE_URL: http://$GATEWAY_URL/productpage

echo "!!!!!!!! Check conteiner for available !!!!!!!!"
until curl curl http://$GATEWAY_URL/productpage | grep -o "<title>.*</title>"; do
  echo "Conteiner productpage - sleeping"
  sleep 1
done
echo "Conteiner productpage is up - executing command"




# set envs for tests non vesioned apps
productpag_answer=$(curl http://$GATEWAY_URL/productpage | grep -o "<title>.*</title>")
details_answer=$(curl http://$GATEWAY_URL/productpage | grep -o "Book Details")
ratings_answer=$(curl http://$GATEWAY_URL/productpage | grep -o "Book Reviews")
status_code=$(curl -o /dev/null -s -w "%{http_code}" http://$GATEWAY_URL/productpage; echo)

echo "productpage - the productpage microservice calls the details and reviews microservices to populate the page."
echo "details - the details microservice contains book information."
echo "ratings - the ratings microservice contains book ranking information that accompanies a book"
echo "reviews - the reviews microservice contains book reviews. It also calls the ratings microservice."
echo ""
echo "There are 3 versions of the reviews microservice:"
echo "Version v1 - doesn't call the ratings service"
echo "Version v2 - calls the ratings service, and displays each rating as 1 to 5 black stars."
echo "Version v3 - calls the ratings service, and displays each rating as 1 to 5 red stars."
echo
echo "Print env info"

kubectl get svc,deployment,pods -o wide 

echo "Test Bookinfo Application"
echo "...."
echo "......."
echo ".........."
echo "Test status code of main url..."
if [[ $status_code == 200 ]]; then
  echo "main url  status code is: "$status_code"  ......"
  echo "main url status code Test Passed OK."
else
  echo "Problem main url not passed, wrong status: "$status_code""
fi

echo "Test content of main url page and productpage app..."
if [[ $productpag_answer == *"<title>Simple Bookstore App</title>"* ]]; then
  echo "main url test answer is "$productpag_answer"  ......"
  echo "main url Test Passed OK. "
  echo "App productpag. Test Passed OK. "
else
  echo "Problem main url not passed, wrong answer "$productpag_answer""
fi

echo "Test details app..."
if [[ $details_answer == *"Book Details"* ]]; then
  echo "main url test answer is "$details_answer"  ......"
  echo "main url Test Passed OK. "
else
  echo "Problem main url not passed, wrong answer "$details_answer""
fi


echo "Test ratings app..."
if [[ $ratings_answer == *"Book Reviews"* ]]; then
  echo "main url test answer is "$ratings_answer"  ......"
  echo "main url Test Passed OK. "
else
  echo "Problem main url not passed, wrong answer "$ratings_answer""
fi


echo "Test reviews v1 app..."
echo "Apply destination rules for reviews v1 app"
echo "Version v1 - doesn't call the ratings service. No stars"
kubectl apply -f samples/bookinfo/networking/destination-rule-all.yaml
echo "Set destination rules to v1 of reviews app"
kubectl apply -f samples/bookinfo/networking/virtual-service-reviews-test-v2.yaml
echo "Test reviews v2 app..."
echo "Apply destination rules for reviews v2 app"
cat >samples/bookinfo/networking/test-reviews-v2.yaml <<EOF 
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: reviews
spec:
  hosts:
    - reviews
  http:
  - route:
    - destination:
        host: reviews
        subset: v2
EOF
kubectl apply -f samples/bookinfo/networking/test-reviews-v2.yaml
echo "Set destination rules to v2 of reviews app"
echo "Version v2 - calls the ratings service, and displays each rating as 1 to 5 black stars."
sleep 3
productpag_reviewsv2=$(curl http://$GATEWAY_URL/productpage | grep -o "<font color=".*">")
echo $productpag_reviewsv2

if [[ $productpag_reviewsv2 == *"black"* ]]; then
  echo "reviews v2 app is OK. Black stars found"
  echo "reviews v2 app Test Passed OK. "
else
  echo "reviews v2 app is faled. Black stars not found "
fi



echo "Test reviews v3 app..."
echo "Apply destination rules for reviews v3 app"
echo "Set destination rules to v3 of reviews app"
echo "Version v3 - calls the ratings service, and displays each rating as 1 to 5 red stars."
cat > samples/bookinfo/networking/test-reviews-v3.yaml <<EOF 
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: reviews
spec:
  hosts:
    - reviews
  http:
  - route:
    - destination:
        host: reviews
        subset: v3
EOF
kubectl apply -f samples/bookinfo/networking/test-reviews-v3.yaml
sleep 3
productpag_reviewsv3=$(curl http://$GATEWAY_URL/productpage | grep -o "<font color=".*">")
echo $productpag_reviewsv3

if [[ $productpag_reviewsv3 == *"red"* ]]; then
  echo "reviews v3 app is OK. Red stars found"
  echo "reviews v3 app Test Passed OK. "
else
  echo "reviews v3 app is faled. Red stars not found "
fi


clear
kubectl delete -f samples/bookinfo/networking/virtual-service-all-v1.yaml


echo "Test main url performance score"
sudo apt-get install apache2-utils -y
ab -c 10 -n 100 http://$GATEWAY_URL/productpage

sudo apt install siege -y
siege --log=/tmp/siege --concurrent=1 -q --internet --time=1M http://$GATEWAY_URL/productpage
cat /tmp/siege