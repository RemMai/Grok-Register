# Docker 使用说明

镜像：`remmai/grok-register`（Go CLI + Python Turnstile 脚本 + Chromium + Xvfb）

配套 compose：清障栈 WARP → Privoxy → FlareSolverr 与 app 同一网络。

## 构建

```bash
cd Grok-Register-go   # 或本仓库根目录
docker compose build
# 或仅镜像
docker build -t remmai/grok-register:latest .
```

## 启动整栈

```bash
docker compose up -d
docker compose ps
```

数据目录默认 Docker volume `grok-data`，挂载到容器内 `/data`（即 `GROK_HOME`）。

## 配置

首次启动会把示例配置拷到 `/data/config.env`。请改邮箱与密钥：

```bash
docker compose exec grok sh -c 'vi /data/config.env'
# 或在宿主机 bind-mount：
# GROK_DATA_DIR=./data docker compose up -d
```

容器内默认代理（compose 网络）：

| 变量 | 默认 |
|------|------|
| `REGISTER_PROXY` | `http://privoxy:8118` |
| `FLARESOLVERR_URL` | `http://flaresolverr:8191` |
| `CLEARANCE_PROXY` | `http://privoxy:8118` |

## 运行注册

```bash
# 推荐：在已 up 的容器里 exec
docker compose exec grok grok start -t 5 --thread 2
docker compose exec grok grok status
docker compose exec grok grok logs -f
docker compose exec grok grok stop

# 或一次性前台跑（容器随任务结束）
docker compose run --rm grok start -t 5 --thread 2
```

产物：`/data/outputs/<run-id>/{SSO,CPA}/`

## 仅跑 app（不用内置 clearance）

```bash
docker run --rm -it \
  -e GROK_HOME=/data \
  -e CLEARANCE_ENABLED=0 \
  -v grok-data:/data \
  remmai/grok-register:latest start -t 3 --thread 1
```

## 说明

- Turnstile 使用容器内 Chromium + Xvfb（`CHROME_PATH=/usr/bin/chromium`）。
- 纯 headless 对 CF 成功率较低；镜像默认起虚拟显示。
- `start` 会 fork worker；entrypoint 会等待 worker，避免容器立刻退出。
- 默认 `command: idle`：`compose up` 后容器保持运行，方便 `exec`。

## GitHub Actions / GHCR

仓库已配置 [`.github/workflows/docker.yml`](.github/workflows/docker.yml)：

- **触发**: push 到 `main`（Dockerfile/相关代码变更）、tag `v*`、PR、手动 `workflow_dispatch`
- **构建**: `linux/amd64`
- **推送**: PR 只 build；merge/push 后推到 **GHCR**

```bash
# 登录（GitHub PAT 需 read:packages）
echo $GITHUB_TOKEN | docker login ghcr.io -u USERNAME --password-stdin

# 按仓库 owner 小写拉取（示例）
docker pull ghcr.io/remmai/grok-register:latest
# 或
docker pull ghcr.io/charles-0509/grok-register:latest
```

镜像名 = `ghcr.io/<owner>/<repo>`（全小写）。Actions 页可看构建日志。
