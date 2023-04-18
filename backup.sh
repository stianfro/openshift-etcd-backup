#!/bin/bash
################################################################################
# backup.sh OpenShift etcd backup script
################################################################################
#
# Copyright (C) 2021 Adfinis AG
#                    https://adfinis.com
#                    info@adfinis.com
#
# This program is free software: you can redistribute it and/or
# modify it under the terms of the GNU Affero General Public
# License as published  by the Free Software Foundation, version
# 3 of the License.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public
# License  along with this program.
# If not, see <http://www.gnu.org/licenses/>.
#
# Please submit enhancements, bugfixes or comments via:
# https://github.com/adfinis-sygroup/openshift-etcd-backup
#
# Authors:
#  Cyrill von Wattenwyl <cyrill.vonwattenwyl@adfinis.com>


set -xeuo pipefail

# set proper umask
umask "${OCP_BACKUP_UMASK}"

# validate expire type
case "${OCP_BACKUP_EXPIRE_TYPE}" in
    days|count|never) ;;
    *) echo "backup.expiretype needs to be one of: days,count,never"; exit 1 ;;
esac

# validate  expire numbers
if [ "${OCP_BACKUP_EXPIRE_TYPE}" = "days" ]; then
  case "${OCP_BACKUP_KEEP_DAYS}" in
    ''|*[!0-9]*) echo "backup.expiredays needs to be a valid number"; exit 1 ;;
    *) ;;
  esac
elif [ "${OCP_BACKUP_EXPIRE_TYPE}" = "count" ]; then
  case "${OCP_BACKUP_KEEP_COUNT}" in
    ''|*[!0-9]*) echo "backup.expirecount needs to be a valid number"; exit 1 ;;
    *) ;;
  esac
fi

# make dirname and cleanup paths
BACKUP_FOLDER="$( date "${OCP_BACKUP_DIRNAME}")" || { echo "Invalid backup.dirname" && exit 1; }
BACKUP_PATH="$( realpath -m "${OCP_BACKUP_SUBDIR}/${BACKUP_FOLDER}" )"
BACKUP_PATH_POD="$( realpath -m "/backup/${BACKUP_PATH}" )"
BACKUP_ROOTPATH="$( realpath -m "/backup/${OCP_BACKUP_SUBDIR}" )"

# make nescesary directorys
mkdir -p "/host/var/tmp/etcd-backup"
mkdir -p "${BACKUP_PATH_POD}"

# create backup to temporary location
chroot /host /usr/local/bin/cluster-backup.sh /var/tmp/etcd-backup

# move files to pvc and delete temporary files
mv /host/var/tmp/etcd-backup/* "${BACKUP_PATH_POD}"
rm -rv /host/var/tmp/etcd-backup

# upload to s3 if S3_ENDPOINT variable is not empty
if [ -z "${S3_ENDPOINT}" ]; then
  # verify all variables
  if [ -z "${S3_ACCESSKEY}" ]; then
    echo "S3_ACCESSKEY is not set"
    exit 1
  fi
  if [ -z "${S3_SECRETKEY}" ]; then
    echo "S3_SECRETKEY is not set"
    exit 1
  fi
  if [ -z "${S3_BUCKET}" ]; then
    echo "S3_BUCKET is not set"
    exit 1
  fi

  # create alias for mc cli
  mc alias set backup "${S3_ENDPOINT}" "${S3_ACCESSKEY}" "${S3_SECRETKEY}"

  # upload files
  mc cp --recursive "${BACKUP_PATH_POD}" backup/"${S3_BUCKET}"

  # expire s3 backup
  if [ "${OCP_BACKUP_EXPIRE_TYPE}" = "days" ]; then
    mc rm --recursive --force --older-than "${OCP_BACKUP_KEEP_DAYS}"d backup/"${S3_BUCKET}"
  fi
fi

# expire backup
if [ "${OCP_BACKUP_EXPIRE_TYPE}" = "days" ]; then
  find "${BACKUP_ROOTPATH}" -mindepth 1 -maxdepth 1  -type d -mtime "+${OCP_BACKUP_KEEP_DAYS}" -exec rm -rv {} +
elif [ "${OCP_BACKUP_EXPIRE_TYPE}" = "count" ]; then
  # shellcheck disable=SC3040,SC2012
  ls -1tp "${BACKUP_ROOTPATH}" | awk "NR>${OCP_BACKUP_KEEP_COUNT}" | xargs -I{} rm -rv "${BACKUP_ROOTPATH}/{}"
fi
