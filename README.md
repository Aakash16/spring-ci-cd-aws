# spring-ci-cd-aws
This is a spring boot project to demonstrate CI CD workflow integrated with AWS using GitHub Actions.
We deploy [SpringBoot](http://projects.spring.io/spring-boot/) Restful web service application with [Docker](https://www.docker.com/) and with [Kubernetes](https://kubernetes.io/)

#### Prerequisite

Installed:   
[Docker](https://www.docker.com/)   
[git](https://www.digitalocean.com/community/tutorials/how-to-contribute-to-open-source-getting-started-with-git)

Optional:   
[Docker-Compose](https://docs.docker.com/compose/install/)   
[Java 1.8 or 11.1](https://www.oracle.com/technetwork/java/javase/overview/index.html)   
[Maven 3.x](https://maven.apache.org/install.html)


#### Steps

##### Clone source code from git
```
git clone https://github.com/aakash16/spring-ci-cd-aws
```

##### Build Docker image
```
docker build -t="spring-boot-cicd" .
```
Maven build will be executed during creation of the docker image.

>Note:if you run this command for first time it will take some time in order to download base image from [DockerHub](https://hub.docker.com/)

##### Run Docker Container
```
docker run -p 8080:8080 -it --rm spring-boot-cicd
```

##### Test application

```
curl localhost:8080
```

response should be:
```
Hello World
```

#####  Stop Docker Container:
```
docker stop `docker container ls | grep "spring-boot-cicd:*" | awk '{ print $1 }'`
```

### Run with docker-compose

Build and start the container by running

```
docker-compose up -d 
```

#### Test application with ***curl*** command

```
curl localhost:8080
```

response should be:
```
Hello World
```

##### Stop Docker Container:
```
docker-compose down
```

### Deploy under the Kubernetes cluster

#### Prerequisite

##### MiniKube

Installed:
[MiniKube](https://www.digitalocean.com/community/tutorials/how-to-use-minikube-for-local-kubernetes-development-and-testing)

Start minikube with command:
```
minikube start
```


#### Retrieve and deploy application

```
kubectl create deployment spring-boot-cicd --image=aakash16/docker-spring-boot-cicd:latest
```

#### Expose deployment as a Kubernetes Service
```
kubectl expose deployment spring-boot-cicd --type=NodePort --port=8080
```

#### Check whether the service is running
```
kubectl get service spring-boot-cicd
```

response should be something like this:
```
NAME                TYPE       CLUSTER-IP      EXTERNAL-IP   PORT(S)          AGE
spring-boot-cicd   NodePort   xx.xx.xxx.xxx   <none>        8080:xxxxx/TCP   59m
```

#### Retrieve URL for application(spring-boot-cicd)
```
minikube service spring-boot-cicd --url
```

response will be http..., e.g:
```
http://127.0.0.1:44963
```

#### Test application with ***curl*** command(note: port is randomly created)

```
curl 127.0.0.1:44963
```

response should be:
```
Hello World
```

