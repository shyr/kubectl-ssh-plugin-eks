#!/usr/bin/env bash
# Global options
pkgtype=''  # defined in get_sysinfo
os_name=''  # defined in get_sysinfo
getpublicip='' # defined in get_sysinfo
KUBECTL_PLUGINS_LOCAL_FLAG_CLOUD_PROVIDER=aws

get_sysinfo()
{
  found_file=""
  for f in system-release redhat-release; do
    [ -f "/etc/${f}" ] && found_file="${f}" && break
  done

  case "${found_file}" in
    system-release)
      pkgtype="rpm"
      if grep --quiet "Linux" /etc/${found_file}; then
        os_name="Linux"
      elif grep --quiet "Red Hat" /etc/${found_file}; then
        os_name="Linux"
      fi
      ;;
    redhat-release )
      pkgtype="deb"
      if grep --quiet "8" /etc/${found_file}; then
        os_name="Linux"
      fi
      ;;
    *)
      OS=$(uname -s)
      if [ "${OS}" == "Darwin" ]; then
        os_name="Darwin"
      fi
      ;;
    *)
      echo "Unsupported OS detected."
      exit 1
      ;;
  esac
  
}

get_publicIP()
{ 
  get_sysinfo
  case "${os_name}" in
    Linux)
      getpublicip="$HOME/.kube/plugins/kubectl-ssh-plugin-eks/getpublicip_linux" 2>&1
      ;;
    Darwin)
      getpublicip="$HOME/.kube/plugins/kubectl-ssh-plugin-eks/getpublicip_darwin" 2>&1
      ;;
  esac
}

if [ "$KUBECTL_PLUGINS_LOCAL_FLAG_SELECTOR" == "" ] && [ -z "$1" ]
then
  echo "Node name cannot be empty"
  exit 1
else [ "$KUBECTL_PLUGINS_LOCAL_FLAG_CLOUD_PROVIDER" == "aws" ]
  if [ "$KUBECTL_PLUGINS_LOCAL_FLAG_SELECTOR" == "" ]
  then
    selector=""
    path="{.spec.externalID}"
    pathregion="{.spec.providerID}"
  else
    selector="-l $KUBECTL_PLUGINS_LOCAL_FLAG_SELECTOR"
    path="{.items[0].spec.externalID}"
    pathregion="{.items[0].spec.providerID}"
  fi
  instanceID=$(kubectl get node $1 -o jsonpath="${path}" $selector)
  region=$(kubectl get node $1 -o jsonpath="${pathregion}" $selector | awk -F/ '{print $4}')
  get_publicIP
  publicIP=`${getpublicip} -region=${region%?} -instanceid=$instanceID`
  echo "${publicIP}"
  [[ ! -z "${publicIP}" ]] && ssh -i ${KUBECTL_PLUGINS_LOCAL_FLAG_IDENTITY_FILE} ${KUBECTL_PLUGINS_LOCAL_FLAG_SSH_USER}@$publicIP || echo "Can't SSH"; exit 1;
fi