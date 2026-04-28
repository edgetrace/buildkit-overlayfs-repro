group "default" {
  targets = ["a", "b", "c"]
}

target "a" {
  dockerfile = "Dockerfile.a"
  context    = "."
  tags       = ["repro-a:latest"]
}

target "b" {
  dockerfile = "Dockerfile.b"
  context    = "."
  tags       = ["repro-b:latest"]
}

target "c" {
  dockerfile = "Dockerfile.c"
  context    = "."
  tags       = ["repro-c:latest"]
}
