from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.core.config import settings
from app.api.v1.router import api_router
from app.services.fpl.client import fpl_client


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup actions
    yield
    # Shutdown actions
    await fpl_client.close()


app = FastAPI(
    title=settings.APP_NAME,
    version=settings.APP_VERSION,
    description="Backend API and analytical engine for FPL IQ (Fantasy Premier League Command Centre).",
    lifespan=lifespan
)

# Enable CORS for Flutter mobile client & future web dashboard
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(api_router, prefix=settings.API_V1_PREFIX)


@app.get("/")
async def root():
    return {
        "message": "Welcome to FPL IQ API",
        "docs_url": "/docs",
        "health_check": f"{settings.API_V1_PREFIX}/health"
    }
