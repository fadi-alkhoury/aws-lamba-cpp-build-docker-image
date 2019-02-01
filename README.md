# Create a Docker image for building C++ AWS lambda functions

This repository contains a Dockerfile to create a docker image suitable for building C++ [AWS lambda functions](https://aws.amazon.com/lambda/).


## How to use

Prerequisites
- install Docker and git on your system
- install the AWS CLI if you intend to push your docker image to ECR

Start Docker
```
sudo service docker start
```

Clone this repository
```
git clone https://github.com/fadi-alkhoury/aws-lamba-cpp-build-docker-image.git
```

Add any files you need for building the image, and remove unneeded files
```
cd aws-lamba-cpp-build-docker-image

mkdir share
cp path/to/any/file/you/need/to/make/available/to/docker share
rm any/files/you/dont/need

Modify the `Dockerfile` if needed, and then build the docker image
docker build -t build-env-cpp .
```

Now you can run your build commands inside the docker image
```
docker run -it --entrypoint sh build-env-cpp -c bash

mkdir path/to/your/cpp/lambda/build
cd path/to/your/cpp/lambda/build
cmake .. -DCMAKE_BUILD_TYPE=RELEASE
make
make aws-lambda-package-my-lambda

#deploy the lambda with cloudformation, if desired ...
```

You can then push your image to ECR so that it can be used, for example, by [AWS CodeBuild](https://aws.amazon.com/codebuild/) within a continuous deployment pipeline 
```
myAwsAccountNumber=1111111111
myRegion=us-east-1

aws ecr create-repository --repository-name build-env-cpp --region ${myRegion}
docker tag build-env-cpp ${myAwsAccountNumber}.dkr.ecr.${myRegion}.amazonaws.com/build-env-cpp

$(aws ecr get-login --registry-ids ${myAwsAccountNumber} --region ${myRegion} --no-include-email)

docker push ${myAwsAccountNumber}.dkr.ecr.${myRegion}.amazonaws.com/build-env-cpp
```
