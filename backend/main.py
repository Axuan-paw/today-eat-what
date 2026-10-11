"""今天吃什么 · V2.0 后端入口

V2-A 阶段：只验证 FastAPI 宿主能跑起来（/ 与 /api/health）。
V2-C 起，/api/dishes 等业务路由会挂在这个 app 对象上。
"""

from fastapi import FastAPI

app = FastAPI(title="今天吃什么 API", version="2.0")


@app.get("/")
def root():
    return {"message": "今天吃什么 · V2.0 后端已启动"}


@app.get("/api/health")
def health():
    return {"status": "ok"}
