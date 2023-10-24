FROM registry.access.redhat.com/ubi8-minimal:8.8-1072.1697626218

LABEL org.opencontainers.image.authors="Stian Frøystein <https://github.com/stianfro>"
LABEL org.opencontainers.image.vendor="Stian Frøystein"

COPY backup.sh /usr/local/bin/backup.sh

RUN microdnf update -y && rm -rf /var/cache/yum
RUN microdnf install findutils tar gzip openssl -y && microdnf clean all
RUN curl https://dl.min.io/client/mc/release/linux-amd64/mc --create-dirs -o /usr/local/bin/mc &&\
    chmod 755 /usr/local/bin/mc

CMD ["/usr/local/bin/backup.sh"]
