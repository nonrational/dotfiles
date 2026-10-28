# pseudo-random password generator; strips characters that need quoting.
# Oversamples then truncates so the result is len characters despite the strip.
function prpg --argument-names len
  test -n "$len"; or set len 16
  openssl rand -base64 (math $len '*' 2) | tr -d '/+=\n' | head -c $len
end
