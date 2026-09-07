#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "$0")/.." && pwd)
public_key_file=${SPARKLE_PUBLIC_KEY_FILE:-$repo_root/.sparkle/sparkle-public.pem}

[[ -f "$public_key_file" ]] || {
    echo "ERROR: Sparkle public key not found: $public_key_file" >&2
    exit 1
}

SPARKLE_PUBLIC_KEY_FILE="$public_key_file" ruby -rbase64 -ropenssl -e '
  public_key_path = ENV.fetch("SPARKLE_PUBLIC_KEY_FILE")
  begin
    public_key = Base64.strict_decode64(File.read(public_key_path).strip)
  rescue ArgumentError
    abort "ERROR: Sparkle public key is not valid base64"
  end
  abort "ERROR: Sparkle public key must decode to 32 bytes" unless public_key.bytesize == 32

  private_key_text = ENV["SPARKLE_PRIVATE_KEY"]
  exit 0 if private_key_text.nil? || private_key_text.empty?

  begin
    secret = Base64.strict_decode64(private_key_text.strip)
  rescue ArgumentError
    abort "ERROR: Sparkle private key is not valid base64"
  end

  expected_public_key = case secret.bytesize
                        when 32
                          private_key_der = ["302e020100300506032b657004220420"].pack("H*") + secret
                          OpenSSL::PKey.read(private_key_der).public_to_der.byteslice(-32, 32)
                        when 96
                          abort "ERROR: Legacy 96-byte Sparkle private keys are unsupported; migrate to a 32-byte seed"
                        else
                          abort "ERROR: Sparkle private key must decode to a 32-byte seed"
                        end

  abort "ERROR: Sparkle public key does not match the private signing key" \
    unless public_key == expected_public_key
'

echo "Sparkle key validation passed."
