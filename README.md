# bisheng-deploy-to-k8s

[Bisheng](https://github.com/dataelement/bisheng) 的 Kubernetes Helm Chart 部署方案，将 Bisheng 从 Docker Compose 迁移到 Kubernetes 原生部署。

## 概述

[Bisheng](https://github.com/dataelement/bisheng) 是数元科技开源的低代码大语言模型应用开发平台。官方仅提供 Docker Compose 部署方式，本项目将其改造为标准的 Helm Chart，支持一键部署到 Kubernetes 集群。

**包含组件：**

| 组件 | 说明 | 默认镜像 |
|------|------|---------|
| MySQL | 关系型数据库 | `mysql:8.0` |
| Redis | 缓存 / Celery Broker | `redis:7.0.4` |
| Elasticsearch | 全文搜索引擎 | `bitnamilegacy/elasticsearch:8.12.0` |
| MinIO | 对象存储（Bisheng + Milvus 共用） | `minio/minio:RELEASE.2023-03-20T20-16-18Z` |
| Milvus | 向量数据库（含 etcd） | `milvusdb/milvus:v2.5.10` |
| Backend | API 服务 + Celery Worker | `dataelement/bisheng-backend:v2.4.0-beta1-fix` |
| Frontend | Nginx + React 前端 | `dataelement/bisheng-frontend:v2.4.0-beta1-fix` |

## 前置条件

- Kubernetes 1.24+
- Helm 3.8+
- StorageClass 支持 ReadWriteOnce（如 Ceph RBD、NFS、hostPath 等）

## 快速开始

```bash
# 1. 克隆仓库
git clone https://github.com/yhappy-you/bisheng-deploy-to-k8s.git
cd bisheng-deploy-to-k8s

# 2. 创建命名空间
kubectl create namespace bisheng

# 3. 安装
helm install bisheng ./bisheng-helm -n bisheng

# 4. 查看状态
kubectl get pods -n bisheng
kubectl get ingress -n bisheng
```

## 配置

### 最小化配置

```bash
helm install bisheng ./bisheng-helm \
  --set mysql.auth.rootPassword=YOUR_MYSQL_PASSWORD \
  -n bisheng
```

> **注意：** `mysql.auth.rootPassword` 必须设置。默认 `config.yaml` 中的 `database_url` 使用了加密后的密码 `1234`，首次部署建议使用 `1234`，后续通过 Bisheng 管理界面修改。

### 使用镜像代理

国内环境拉取 Docker Hub 镜像较慢，可设置全局镜像代理前缀：

```bash
helm install bisheng ./bisheng-helm \
  --set global.imageRegistry=your-mirror-registry \
  --set mysql.auth.rootPassword=1234 \
  -n bisheng
```

### 生产环境配置

项目提供了生产环境示例配置：

```bash
helm install bisheng ./bisheng-helm \
  -f examples/values-production.yaml \
  -n bisheng
```

生产环境配置包含：
- Traefik Ingress 配置示例
- 自定义 Ingress 域名示例
- MySQL 密码配置

### 自定义 Ingress

```bash
helm install bisheng ./bisheng-helm \
  --set ingress.enabled=true \
  --set ingress.className=traefik \
  --set ingress.host=bisheng.example.com \
  --set ingress.annotations.'traefik\.ingress\.kubernetes\.io/router\.entrypoints'=websecure \
  -n bisheng
```

### 禁用部分组件

如果集群中已有 MySQL/Redis 等基础设施，可以禁用内置组件：

```bash
helm install bisheng ./bisheng-helm \
  --set mysql.enabled=false \
  --set redis.enabled=false \
  -n bisheng
```

> 禁用内置组件后，需要手动修改 Backend ConfigMap 中的 `database_url` 和 `redis_url` 指向外部服务。

## 参数说明

### 全局配置

| 参数 | 说明 | 默认值 |
|------|------|--------|
| `global.imageRegistry` | 全局镜像仓库前缀 | `""` |
| `global.storageClass` | StorageClass 名称 | `""` |
| `global.timezone` | 时区 | `Asia/Shanghai` |

### MySQL

| 参数 | 说明 | 默认值 |
|------|------|--------|
| `mysql.enabled` | 是否部署 MySQL | `true` |
| `mysql.image` | 镜像 | `mysql:8.0` |
| `mysql.auth.rootPassword` | root 密码（必填） | `""` |
| `mysql.auth.database` | 数据库名 | `bisheng` |
| `mysql.persistence.size` | 存储大小 | `20Gi` |

### Backend

| 参数 | 说明 | 默认值 |
|------|------|--------|
| `backend.image` | 后端镜像 | `dataelement/bisheng-backend:v2.4.0-beta1-fix` |
| `backend.replicaCount` | API 副本数 | `1` |
| `backend.config.logLevel` | 日志级别 | `INFO` |
| `backend.env.milvusConnectionArgs` | Milvus 连接参数 | (见 values.yaml) |
| `backend.env.elasticsearchUrl` | ES 地址 | `http://elasticsearch:9200` |
| `backend.env.minioEndpoint` | MinIO 地址 | `minio:9000` |
| `backend.persistence.size` | 数据存储大小 | `10Gi` |

完整参数请参考 [values.yaml](bisheng-helm/values.yaml)。

## 架构

```
                    ┌─────────────┐
                    │   Ingress   │
                    │ (Traefik)   │
                    └──────┬──────┘
                           │
                    ┌──────▼──────┐
                    │   Frontend  │
                    │  (Nginx)    │
                    │  :3001      │
                    └──┬─────┬───┘
                       │     │
              ┌────────▼─┐  ┌▼──────────┐
              │ Backend  │  │   MinIO   │
              │   API    │  │  :9000    │
              │  :7860   │  └───────────┘
              └────┬─────┘
                   │
    ┌──────────┬───┴───┬──────────┐
    │          │       │          │
┌───▼───┐ ┌───▼───┐ ┌▼────┐ ┌───▼────┐
│ MySQL │ │ Redis │ │ ES  │ │ Milvus │
│ :3306 │ │ :6379 │ │9200 │ │ :19530 │
└───────┘ └───────┘ └─────┘ └───┬────┘
                                  │
                            ┌─────▼─────┐
                            │   etcd    │
                            │  :2379    │
                            └───────────┘
```

- **Frontend (Nginx)** 作为内部路由器，处理静态文件、API 反向代理和 WebSocket 升级
- **Backend API** 提供 REST API，**Worker** 运行 Celery 异步任务（知识库处理、工作流执行等）
- **MinIO** 被 Bisheng 对象存储和 Milvus 向量存储共用

## 与官方 Docker Compose 的对应关系

| Docker Compose 服务 | Helm Chart 组件 | K8s 资源类型 |
|---------------------|----------------|-------------|
| `mysql` | `mysql` | StatefulSet |
| `redis` | `redis` | StatefulSet |
| `backend` | `backend` | Deployment |
| `backend_worker` | `worker` | Deployment |
| `frontend` | `frontend` | Deployment |
| `elasticsearch` | `elasticsearch` | StatefulSet |
| `etcd` | `milvus-etcd` | StatefulSet |
| `minio` | `minio` | StatefulSet |
| `milvus` | `milvus` | Deployment |

## 常用命令

```bash
# 升级
helm upgrade bisheng ./bisheng-helm -n bisheng

# 查看渲染的 YAML（不安装）
helm template bisheng ./bisheng-helm

# 卸载
helm uninstall bisheng -n bisheng

# 查看 Pod 日志
kubectl logs -f deployment/bisheng-backend -n bisheng
kubectl logs -f deployment/bisheng-worker -n bisheng
```

## 已知限制

- MySQL `config.yaml` 中的 `database_url` 使用 Bisheng 内部加密，首次部署需使用默认密码 `1234`，后续通过管理界面修改
- Worker 将所有 Celery 队列（knowledge、workflow、beat、linsight、default）运行在单个 Pod 中，不支持独立扩缩
- Milvus 以 standalone 模式部署，不支持集群模式

## 致谢

- [Bisheng](https://github.com/dataelement/bisheng) - 数元科技低代码 LLM 应用平台
- [Milvus](https://github.com/milvus-io/milvus) - 开源向量数据库
- [MinIO](https://github.com/minio/minio) - 高性能对象存储

## License

[MIT](LICENSE)
