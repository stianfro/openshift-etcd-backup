FROM registry.access.redhat.com/ubi8-minimal:8.7-1107

LABEL org.opencontainers.image.authors="Stian Frøystein <https://github.com/stianfro>"
LABEL org.opencontainers.image.vendor="Stian Frøystein"

COPY backup.sh /usr/local/bin/backup.sh

RUN microdnf update -y && rm -rf /var/cache/yum
RUN microdnf install findutils -y && microdnf clean all

CMD ["/usr/local/bin/backup.sh"]
