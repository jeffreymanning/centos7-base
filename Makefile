LOCAL_IMAGE=centos7-base
SPARK_IMAGE=jeffreymanning/$(LOCAL_IMAGE)
versionDef=1.0.0
version?=$(versionDef)


# If you're pushing to an integrated registry
# in Openshift, SPARK_IMAGE will look something like this
# SPARK_IMAGE=172.30.242.71:5000/myproject/openshift-spark

.PHONY: build clean push

build:
	docker build -t $(LOCAL_IMAGE):$(version) -t $(LOCAL_IMAGE):latest .

clean:
	docker rmi $(LOCAL_IMAGE)

push: build
	docker tag $(LOCAL_IMAGE) $(SPARK_IMAGE)
	docker push $(SPARK_IMAGE)

