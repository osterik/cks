TODO: This isn't a very good example, since the `ping_pong` image generates load itself(!), so adding pods doesn't reduce the overall load. It needs to be redesigned so that the load generator is separate, then HPA configuration will only be needed for consumers.

After that the `worker/files/tests.bats` could be replaced with correct one, see https://github.com/ViktorUJ/cks/issues/268
