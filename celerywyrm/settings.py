"""bookwyrm settings and configuration"""

from bookwyrm.settings import *

QUERY_TIMEOUT = env.int("CELERY_QUERY_TIMEOUT", env.int("QUERY_TIMEOUT", 30))

# pylint: disable=line-too-long
if (password := env("REDIS_BROKER_PASSWORD", None)) is not None:
    REDIS_BROKER_PASSWORD = requests.utils.compat(password)
else:
    REDIS_BROKER_PASSWORD = None
REDIS_BROKER_HOST = env("REDIS_BROKER_HOST", "redis_broker")
REDIS_BROKER_PORT = env("REDIS_BROKER_PORT", 6379)
REDIS_BROKER_SOCKET = env("REDIS_BROKER_SOCKET", None)
REDIS_BROKER_DB_INDEX = env("REDIS_BROKER_DB_INDEX", 0)
REDIS_BROKER_URL = env(
    "REDIS_BROKER_URL",
    f"redis://:{REDIS_BROKER_PASSWORD}@{REDIS_BROKER_HOST}:{REDIS_BROKER_PORT}/{REDIS_BROKER_DB_INDEX}",
)

# pylint: disable=line-too-long
if REDIS_BROKER_SOCKET is not None:
    CELERY_BROKER_URL = "redis+socket://{}?virtual_host={}".format(
        REDIS_BROKER_SOCKET ,
        REDIS_BROKER_DB_INDEX,
    )
    CELERY_RESULT_BACKEND = CELERY_BROKER_URL
else:
    CELERY_BROKER_URL = "redis://{}:{}/{}".format(
        REDIS_BROKER_HOST,
        REDIS_BROKER_PORT,
        REDIS_BROKER_DB_INDEX,
    )
    CELERY_RESULT_BACKEND = CELERY_BROKER_URL

CELERY_DEFAULT_QUEUE = "low_priority"
CELERY_CREATE_MISSING_QUEUES = True

CELERY_ACCEPT_CONTENT = ["json"]
CELERY_TASK_SERIALIZER = "json"
CELERY_RESULT_SERIALIZER = "json"

CELERY_BEAT_SCHEDULER = "django_celery_beat.schedulers:DatabaseScheduler"
CELERY_TIMEZONE = env("TIME_ZONE", "UTC")

CELERY_WORKER_CONCURRENCY = env("CELERY_WORKER_CONCURRENCY", None)
CELERY_TASK_SOFT_TIME_LIMIT = env("CELERY_TASK_SOFT_TIME_LIMIT", None)

FLOWER_PORT = env.int("FLOWER_PORT", 8888)

INSTALLED_APPS = INSTALLED_APPS + [
    "celerywyrm",
]

ROOT_URLCONF = "celerywyrm.urls"

WSGI_APPLICATION = "celerywyrm.wsgi.application"
