load("@rules_go//go:def.bzl", "go_binary", "go_library")
load("@rules_oci//oci:defs.bzl", "oci_image", "oci_load", "oci_push")
load("@rules_pkg//pkg:mappings.bzl", "pkg_attributes", "pkg_files")
load("@rules_pkg//pkg:tar.bzl", "pkg_tar")

go_library(
    name = "telemetry_lib",
    srcs = [
        "handler.go",
        "main.go",
        "producer.go",
        "trackpoint.go",
    ],
    importpath = "github.com/lai/logistics/telemetry",
    deps = ["@com_github_segmentio_kafka_go//:kafka-go"],
)

go_binary(
    name = "telemetry",
    embed = [":telemetry_lib"],
    visibility = ["//visibility:public"],
)

go_binary(
    name = "telemetry_linux_amd64",
    embed = [":telemetry_lib"],
    goarch = "amd64",
    goos = "linux",
    visibility = ["//visibility:public"],
)

pkg_files(
    name = "telemetry_files",
    srcs = [":telemetry_linux_amd64"],
    attributes = pkg_attributes(mode = "0755"),
    renames = {":telemetry_linux_amd64": "telemetry"},
)

pkg_tar(
    name = "telemetry_layer",
    srcs = [":telemetry_files"],
)

oci_image(
    name = "image",
    base = "@distroless_static_linux_amd64",
    entrypoint = ["/telemetry"],
    tars = [":telemetry_layer"],
)

oci_load(
    name = "image_load",
    image = ":image",
    repo_tags = ["telemetry:latest"],
)

oci_push(
    name = "push",
    image = ":image",
    repository = "ghcr.io/lai/logistics/telemetry",
)
