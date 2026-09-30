#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEFAULT_ENV_FILE="${ROOT_DIR}/.env.production"
ENV_FILE="${1:-}"

SERVICE_NAME="via-landing"
REMOTE_BASE_DIR="/opt/transvias/${SERVICE_NAME}"
COMPOSE_DIR="/opt/transvias/n8n"
DOCKERFILE="${ROOT_DIR}/infra/via/Dockerfile"

usage() {
  cat <<'EOF'
Usage:
  bash scripts/deploy-via-ec2.sh [env-file]

Examples:
  bash scripts/deploy-via-ec2.sh
  bash scripts/deploy-via-ec2.sh .env.production

Description:
  Builds the Next.js standalone server for linux/arm64 and publishes it on the
  existing n8n EC2 instance, behind Caddy, at via.transvias.com.br.

  The container is node:22-alpine running `node server.js`. Caddy proxies the
  whole host, including POST /api/leads.

  Required variables (from env-file, shell, or the defaults below):
    AWS_REGION                 default: sa-east-1 (S3 artifacts bucket)
    N8N_EC2_REGION             region of the n8n EC2 stack (default: us-east-1)
    N8N_STACK_NAME             default: transvias-n8n-prod
    VIA_DOMAIN_NAME            default: via.transvias.com.br

  Lead email (all three, or none):
    RESEND_API_KEY
    LEAD_EMAIL_TO
    LEAD_EMAIL_FROM
  When all three are set, they are written to /opt/transvias/via-landing/.env
  on the server. When none are set, the existing server file is kept. The first
  deploy fails if that file does not exist yet.

  Optional:
    N8N_HOSTED_ZONE_ID         Route53 hosted zone for transvias.com.br
    DEPLOY_S3_BUCKET           default: transvias-deploy-artifacts-<region>
EOF
}

require_var() {
  local name="$1"
  if [[ -z "${!name:-}" ]]; then
    echo "Missing required environment variable: ${name}" >&2
    exit 1
  fi
}

require_cmd() {
  local name="$1"
  if ! command -v "${name}" >/dev/null 2>&1; then
    echo "Missing required command: ${name}" >&2
    exit 1
  fi
}

if [[ "${ENV_FILE}" == "-h" || "${ENV_FILE}" == "--help" ]]; then
  usage
  exit 0
fi

if [[ -z "${ENV_FILE}" && -f "${DEFAULT_ENV_FILE}" ]]; then
  ENV_FILE="${DEFAULT_ENV_FILE}"
fi

if [[ -n "${ENV_FILE}" ]]; then
  if [[ ! -f "${ENV_FILE}" ]]; then
    echo "Env file not found: ${ENV_FILE}" >&2
    exit 1
  fi

  while IFS= read -r line || [[ -n "${line}" ]]; do
    line="${line%$'\r'}"
    [[ -z "${line//[[:space:]]/}" ]] && continue
    [[ "${line}" =~ ^[[:space:]]*# ]] && continue
    [[ "${line}" != *=* ]] && continue

    key="${line%%=*}"
    value="${line#*=}"
    key="${key#"${key%%[![:space:]]*}"}"
    key="${key%"${key##*[![:space:]]}"}"
    [[ -z "${key}" ]] && continue

    if [[ "${value}" =~ ^\".*\"$ ]] || [[ "${value}" =~ ^\'.*\'$ ]]; then
      value="${value:1:-1}"
    fi

    export "${key}=${value}"
  done < "${ENV_FILE}"
fi

export AWS_REGION="${AWS_REGION:-${AWS_DEFAULT_REGION:-sa-east-1}}"
export AWS_DEFAULT_REGION="${AWS_REGION}"
export N8N_EC2_REGION="${N8N_EC2_REGION:-us-east-1}"
export N8N_STACK_NAME="${N8N_STACK_NAME:-transvias-n8n-prod}"
export VIA_DOMAIN_NAME="${VIA_DOMAIN_NAME:-via.transvias.com.br}"
export DEPLOY_S3_BUCKET="${DEPLOY_S3_BUCKET:-transvias-deploy-artifacts-${AWS_REGION}}"

require_var AWS_REGION
require_var N8N_STACK_NAME
require_var VIA_DOMAIN_NAME

require_cmd aws
require_cmd docker
require_cmd tar
require_cmd python3
require_cmd base64
require_cmd curl

ENV_B64="$(python3 - <<'PY'
import base64, os, sys
keys = ("RESEND_API_KEY", "LEAD_EMAIL_TO", "LEAD_EMAIL_FROM")
vals = {key: os.environ.get(key, "") for key in keys}
present = [key for key, value in vals.items() if value]
if present and len(present) != len(keys):
    sys.exit(
        "Provide all of RESEND_API_KEY, LEAD_EMAIL_TO and LEAD_EMAIL_FROM, "
        "or none of them to keep the env file already on the server."
    )
if any("\n" in value or "\r" in value for value in vals.values()):
    sys.exit("Lead email variables cannot contain line breaks.")
if present:
    body = "".join(f"{key}={value}\n" for key, value in vals.items())
    sys.stdout.write(base64.b64encode(body.encode()).decode())
PY
)"

echo "Preparing ViA deploy..."
echo "  AWS_REGION=${AWS_REGION} (S3 artifacts)"
echo "  N8N_EC2_REGION=${N8N_EC2_REGION} (EC2/SSM)"
echo "  N8N_STACK_NAME=${N8N_STACK_NAME}"
echo "  VIA_DOMAIN_NAME=${VIA_DOMAIN_NAME}"
echo "  DEPLOY_S3_BUCKET=${DEPLOY_S3_BUCKET}"
if [[ -n "${ENV_B64}" ]]; then
  echo "  Lead email env: will update the server file"
else
  echo "  Lead email env: keeping the server file"
fi

if ! aws sts get-caller-identity >/dev/null 2>&1; then
  cat >&2 <<'EOF'
AWS credentials are not available locally.

Use one of these approaches before rerunning:
  export AWS_PROFILE=your-profile
  aws sso login --profile your-profile
  export AWS_ACCESS_KEY_ID=...
  export AWS_SECRET_ACCESS_KEY=...
  export AWS_SESSION_TOKEN=...   # if applicable
EOF
  exit 1
fi

echo "Discovering EC2 instance from CloudFormation stack ${N8N_STACK_NAME} (${N8N_EC2_REGION})..."
INSTANCE_ID="$(aws cloudformation describe-stacks \
  --stack-name "${N8N_STACK_NAME}" \
  --region "${N8N_EC2_REGION}" \
  --query 'Stacks[0].Outputs[?OutputKey==`N8nInstanceId`].OutputValue' \
  --output text)"
ELASTIC_IP="$(aws cloudformation describe-stacks \
  --stack-name "${N8N_STACK_NAME}" \
  --region "${N8N_EC2_REGION}" \
  --query 'Stacks[0].Outputs[?OutputKey==`N8nElasticIp`].OutputValue' \
  --output text)"

if [[ -z "${INSTANCE_ID}" || "${INSTANCE_ID}" == "None" ]]; then
  echo "Could not find N8nInstanceId output in stack ${N8N_STACK_NAME}" >&2
  exit 1
fi
if [[ -z "${ELASTIC_IP}" || "${ELASTIC_IP}" == "None" ]]; then
  echo "Could not find N8nElasticIp output in stack ${N8N_STACK_NAME}" >&2
  exit 1
fi

echo "  INSTANCE_ID=${INSTANCE_ID}"
echo "  ELASTIC_IP=${ELASTIC_IP}"

if [[ ! -f "${DOCKERFILE}" ]]; then
  echo "Missing Dockerfile: ${DOCKERFILE}" >&2
  exit 1
fi

ARTIFACT_DIR="${ROOT_DIR}/.deploy"
rm -rf "${ARTIFACT_DIR}/standalone"
mkdir -p "${ARTIFACT_DIR}/standalone"

echo "Building standalone server for linux/arm64..."
DOCKER_BUILDKIT=1 docker build \
  --platform linux/arm64 \
  --target artifact \
  -f "${DOCKERFILE}" \
  -o "type=local,dest=${ARTIFACT_DIR}/standalone" \
  "${ROOT_DIR}"

if [[ ! -f "${ARTIFACT_DIR}/standalone/server.js" ]]; then
  echo "Build did not produce standalone/server.js" >&2
  exit 1
fi

TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
ARTIFACT_FILE="${ARTIFACT_DIR}/${SERVICE_NAME}-${TIMESTAMP}.tar.gz"
echo "Packaging standalone -> ${ARTIFACT_FILE}"
tar -czf "${ARTIFACT_FILE}" -C "${ARTIFACT_DIR}/standalone" .

if ! aws s3api head-bucket --bucket "${DEPLOY_S3_BUCKET}" 2>/dev/null; then
  echo "Bucket ${DEPLOY_S3_BUCKET} not found. Creating..."
  if [[ "${AWS_REGION}" == "us-east-1" ]]; then
    aws s3api create-bucket --bucket "${DEPLOY_S3_BUCKET}" --region "${AWS_REGION}" >/dev/null
  else
    aws s3api create-bucket \
      --bucket "${DEPLOY_S3_BUCKET}" \
      --region "${AWS_REGION}" \
      --create-bucket-configuration "LocationConstraint=${AWS_REGION}" >/dev/null
  fi
  aws s3api put-bucket-encryption \
    --bucket "${DEPLOY_S3_BUCKET}" \
    --server-side-encryption-configuration '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}' >/dev/null
  aws s3api put-public-access-block \
    --bucket "${DEPLOY_S3_BUCKET}" \
    --public-access-block-configuration "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true" >/dev/null
  aws s3api put-bucket-lifecycle-configuration \
    --bucket "${DEPLOY_S3_BUCKET}" \
    --lifecycle-configuration '{"Rules":[{"ID":"expire-old-artifacts","Status":"Enabled","Filter":{"Prefix":""},"Expiration":{"Days":14}}]}' >/dev/null
fi

S3_KEY="${SERVICE_NAME}/$(basename "${ARTIFACT_FILE}")"
S3_URI="s3://${DEPLOY_S3_BUCKET}/${S3_KEY}"
echo "Uploading artifact to ${S3_URI}..."
aws s3 cp "${ARTIFACT_FILE}" "${S3_URI}" >/dev/null

PRESIGNED_URL="$(aws s3 presign "${S3_URI}" --expires-in 3600)"

REMOTE_SCRIPT_FILE="$(mktemp)"
trap 'rm -f "${REMOTE_SCRIPT_FILE}" "${PARAMS_FILE:-}"' EXIT

cat > "${REMOTE_SCRIPT_FILE}" <<REMOTE_HEADER
#!/usr/bin/env bash
set -euo pipefail
export SERVICE_NAME='${SERVICE_NAME}'
export REMOTE_BASE_DIR='${REMOTE_BASE_DIR}'
export COMPOSE_DIR='${COMPOSE_DIR}'
export VIA_DOMAIN_NAME='${VIA_DOMAIN_NAME}'
export PRESIGNED_URL='${PRESIGNED_URL}'
export ENV_B64='${ENV_B64}'
REMOTE_HEADER

cat >> "${REMOTE_SCRIPT_FILE}" <<'REMOTE_BODY'

mkdir -p "${REMOTE_BASE_DIR}/releases" "${REMOTE_BASE_DIR}/app"
RELEASE_DIR="${REMOTE_BASE_DIR}/releases/release-$(date -u +%Y%m%d-%H%M%S)"
mkdir -p "${RELEASE_DIR}"

ARTIFACT_TMP="$(mktemp --suffix=.tar.gz)"
curl -fsSL "${PRESIGNED_URL}" -o "${ARTIFACT_TMP}"
tar -xzf "${ARTIFACT_TMP}" -C "${RELEASE_DIR}"
rm -f "${ARTIFACT_TMP}"

if [[ ! -f "${RELEASE_DIR}/server.js" ]]; then
  echo "Artifact is missing server.js" >&2
  exit 1
fi

if ! command -v rsync >/dev/null 2>&1; then
  dnf install -y rsync
fi

rsync -a --delete "${RELEASE_DIR}/" "${REMOTE_BASE_DIR}/app/"
ls -1dt "${REMOTE_BASE_DIR}/releases"/release-* 2>/dev/null | tail -n +4 | xargs -r rm -rf

if [[ -n "${ENV_B64}" ]]; then
  echo "${ENV_B64}" | base64 -d > "${REMOTE_BASE_DIR}/.env"
  chmod 600 "${REMOTE_BASE_DIR}/.env"
elif [[ ! -s "${REMOTE_BASE_DIR}/.env" ]]; then
  echo "Missing ${REMOTE_BASE_DIR}/.env. Set RESEND_API_KEY, LEAD_EMAIL_TO and LEAD_EMAIL_FROM for the first deploy." >&2
  exit 1
fi

OVERRIDE_FILE="${COMPOSE_DIR}/docker-compose.override.yml"
CADDY_SITES_DIR="${COMPOSE_DIR}/caddy_sites"
CADDY_FRAGMENT="${CADDY_SITES_DIR}/${SERVICE_NAME}.caddyfile"
MARKER_START="# >>> ${SERVICE_NAME}"
MARKER_END="# <<< ${SERVICE_NAME}"

mkdir -p "${CADDY_SITES_DIR}"

OVERRIDE_BLOCK="$(cat <<YAML
${MARKER_START}
  ${SERVICE_NAME}:
    image: node:22-alpine
    restart: unless-stopped
    working_dir: /app
    command: ["node", "server.js"]
    environment:
      HOSTNAME: "0.0.0.0"
      PORT: "3000"
      NODE_ENV: production
    env_file:
      - ${REMOTE_BASE_DIR}/.env
    volumes:
      - ${REMOTE_BASE_DIR}/app:/app
    expose:
      - "3000"
${MARKER_END}
YAML
)"

cat > "${CADDY_FRAGMENT}" <<CADDY
${VIA_DOMAIN_NAME} {
  encode gzip

  reverse_proxy ${SERVICE_NAME}:3000
}
CADDY

export OVERRIDE_FILE OVERRIDE_BLOCK MARKER_START MARKER_END

python3 - <<'PYEOF'
import os, re
path = os.environ["OVERRIDE_FILE"]
block = os.environ["OVERRIDE_BLOCK"]
m_start = os.environ["MARKER_START"]
m_end = os.environ["MARKER_END"]

if not os.path.exists(path):
    with open(path, "w") as f:
        f.write("services:\n" + block + "\n")
else:
    with open(path) as f:
        content = f.read()
    pattern = re.compile(re.escape(m_start) + r".*?" + re.escape(m_end), re.DOTALL)
    if pattern.search(content):
        content = pattern.sub(block, content)
    else:
        if "services:" not in content:
            content = "services:\n" + content
        content = content.rstrip() + "\n" + block + "\n"
    with open(path, "w") as f:
        f.write(content)
PYEOF

cd "${COMPOSE_DIR}"

sed -i '/import \/etc\/caddy\/sites\.d/d' Caddyfile
printf '\nimport /etc/caddy/sites.d/*.caddyfile\n' >> Caddyfile

if ! grep -q "/etc/caddy/sites.d" docker-compose.yml 2>/dev/null; then
  python3 - <<'PYEOF'
import re
path = "docker-compose.yml"
with open(path) as f:
    content = f.read()
content = re.sub(
    r"(\s+- \./Caddyfile:/etc/caddy/Caddyfile:ro)",
    r"\1\n      - ./caddy_sites:/etc/caddy/sites.d:ro",
    content,
    count=1,
)
with open(path, "w") as f:
    f.write(content)
PYEOF
fi

docker compose config >/dev/null
docker compose up -d --force-recreate "${SERVICE_NAME}"
docker compose restart caddy

echo "Remote deploy finished."
REMOTE_BODY

PARAMS_FILE="$(mktemp)"
python3 - "${REMOTE_SCRIPT_FILE}" > "${PARAMS_FILE}" <<'PYEOF'
import json, sys
with open(sys.argv[1]) as f:
    script = f.read()
print(json.dumps({"commands": [script], "executionTimeout": ["900"]}))
PYEOF

echo "Sending SSM RunShellScript to ${INSTANCE_ID} (${N8N_EC2_REGION})..."
COMMAND_ID="$(aws ssm send-command \
  --instance-ids "${INSTANCE_ID}" \
  --document-name "AWS-RunShellScript" \
  --comment "Deploy ${SERVICE_NAME} ${TIMESTAMP}" \
  --parameters "file://${PARAMS_FILE}" \
  --region "${N8N_EC2_REGION}" \
  --query 'Command.CommandId' --output text)"

echo "  COMMAND_ID=${COMMAND_ID}"
echo "Waiting for command to complete..."

while true; do
  STATUS="$(aws ssm get-command-invocation \
    --command-id "${COMMAND_ID}" \
    --instance-id "${INSTANCE_ID}" \
    --region "${N8N_EC2_REGION}" \
    --query 'Status' --output text 2>/dev/null || echo 'Pending')"
  case "${STATUS}" in
    Success)
      echo "SSM command succeeded."
      break
      ;;
    Failed|Cancelled|TimedOut)
      echo "SSM command failed with status: ${STATUS}" >&2
      aws ssm get-command-invocation \
        --command-id "${COMMAND_ID}" \
        --instance-id "${INSTANCE_ID}" \
        --region "${N8N_EC2_REGION}" \
        --query '{Stdout:StandardOutputContent,Stderr:StandardErrorContent}' \
        --output json >&2
      exit 1
      ;;
    *)
      sleep 5
      ;;
  esac
done

aws ssm get-command-invocation \
  --command-id "${COMMAND_ID}" \
  --instance-id "${INSTANCE_ID}" \
  --region "${N8N_EC2_REGION}" \
  --query 'StandardOutputContent' --output text | tail -n 30

if [[ -n "${N8N_HOSTED_ZONE_ID:-}" ]]; then
  echo "Upserting Route53 A record ${VIA_DOMAIN_NAME} -> ${ELASTIC_IP}..."
  CHANGE_BATCH_FILE="$(mktemp)"
  cat > "${CHANGE_BATCH_FILE}" <<JSON
{
  "Comment": "Upsert for ${SERVICE_NAME}",
  "Changes": [{
    "Action": "UPSERT",
    "ResourceRecordSet": {
      "Name": "${VIA_DOMAIN_NAME}",
      "Type": "A",
      "TTL": 60,
      "ResourceRecords": [{"Value": "${ELASTIC_IP}"}]
    }
  }]
}
JSON
  aws route53 change-resource-record-sets \
    --hosted-zone-id "${N8N_HOSTED_ZONE_ID}" \
    --change-batch "file://${CHANGE_BATCH_FILE}" \
    --query 'ChangeInfo.Id' --output text
  rm -f "${CHANGE_BATCH_FILE}"
else
  cat <<DNS

DNS nao configurado automaticamente (N8N_HOSTED_ZONE_ID nao definido).
Crie manualmente um A record no seu provedor de DNS:
  ${VIA_DOMAIN_NAME} -> ${ELASTIC_IP}

Depois adicione ao env file para proximos deploys:
  N8N_HOSTED_ZONE_ID=ZXXXXXXXXXX
DNS
fi

cat <<DONE

Deploy concluído.
  URL: https://${VIA_DOMAIN_NAME}
  Instância: ${INSTANCE_ID}
  Elastic IP: ${ELASTIC_IP}

Na primeira publicação o Caddy pode levar ~1 min para emitir o certificado Let's Encrypt.
Acompanhe os logs com:
  aws ssm start-session --target ${INSTANCE_ID}
  cd ${COMPOSE_DIR} && docker compose logs --tail=100 ${SERVICE_NAME} caddy
DONE
