FROM alpine:3.8

RUN apk add --no-cache \
	alpine-base \
	build-base \
	bash \
	python3 \
	python3-dev

WORKDIR ~/

COPY . .

RUN pip3 install -r requirements.txt

ENTRYPOINT ["bash"]
