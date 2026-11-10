{ procps }:
procps.overrideAttrs (old: {
  patches = (old.patches or []) ++ [ ./procps-android-boottime.patch ];
})
