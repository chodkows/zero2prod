#!/usr/bin/env nu

def main [] {
  # Enable command printing and error handling
  $env.NU_DEBUG = true

  # Set default values for environment variables if not already set
  let DB_PORT = ($env | get -i DB_PORT | default "5432")
  let SUPERUSER = ($env | get -i SUPERUSER | default "postgres")
  let SUPERUSER_PWD = ($env | get -i SUPERUSER_PWD | default "password")
  let APP_USER = ($env | get -i APP_USER | default "app")
  let APP_USER_PWD = ($env | get -i APP_USER_PWD | default "secret")
  let APP_DB_NAME = ($env | get -i APP_DB_NAME | default "newsletter")

  if (which sqlx | is-empty) {
    print "Error: sqlx is not installed"
    print "Use: "
    print "cargo install --version="~0.8" sqlx-cli --no-default-features --features rustls,postgres"
    exit 1
  }

  # Skip Docker if SKIP_DOCKER is set
  if ($env | get -i SKIP_DOCKER | is-empty) {
    # Check if a postgres container is already running
    let RUNNING_POSTGRES_CONTAINER = (docker ps --filter 'name=postgres' --format '{{.ID}}' | str trim)
    if ($RUNNING_POSTGRES_CONTAINER | str length) > 0 {
      print $"there is a postgres container already running, kill it with"
      print $"     docker kill ($RUNNING_POSTGRES_CONTAINER)"
      exit 1
    }
    # Create a unique container name with timestamp
    let CONTAINER_NAME = $"postgres_(date now | format date '%s')"
    # Launch postgres using Docker
    (docker run
      --env $"POSTGRES_USER=($SUPERUSER)"
      --env $"POSTGRES_PASSWORD=($SUPERUSER_PWD)"
      --health-cmd $"pg_isready -U ($SUPERUSER) || exit 1"
      --health-interval=1s
      --health-timeout=5s
      --health-retries=5
      --publish $"($DB_PORT):5432"
      --detach
      --name $"($CONTAINER_NAME)"
      postgres -N 1000)
    # Wait for postgres to be healthy
    mut is_healthy = false
    while not $is_healthy {
      let health_status = (docker inspect -f "{{.State.Health.Status}}" $CONTAINER_NAME | str trim)
      if $health_status == "healthy" {
        $is_healthy = true
      } else {
        print "Postgres is still unavailable - sleeping"
        sleep 1sec
      }
    }
    # Create the application user
    let CREATE_QUERY = $"CREATE USER ($APP_USER) WITH PASSWORD '($APP_USER_PWD)';"
    docker exec -it $CONTAINER_NAME psql -U $SUPERUSER -c $CREATE_QUERY
    # Grant create db privileges to the app user
    let GRANT_QUERY = $"ALTER USER ($APP_USER) CREATEDB;"
    docker exec -it $CONTAINER_NAME psql -U $SUPERUSER -c $GRANT_QUERY
  }
  let DATABASE_URL = $"postgres://($APP_USER):($APP_USER_PWD)@localhost:($DB_PORT)/($APP_DB_NAME)"
  $env.DATABASE_URL = $DATABASE_URL
  sqlx database create
  
}

