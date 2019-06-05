FROM ddfddf/perlsdk

RUN mkdir -p /root/randgenx && mkdir -p /root/conf && mkdir -p /root/result

COPY . /root/randgenx

WORKDIR /root/randgenx