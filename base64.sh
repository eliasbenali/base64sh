#!/bin/sh
test $# -eq 0 && {
	echo "Usage: $0 [input...]"
	exit 1
}

FNAME="$1"
test -r "$FNAME" -o "$FNAME" = "-" || {
	echo "$0: $FNAME: unable to open for input"
	exit 1
}

# Pop front char from list
popc() {
	echo ${1%${1#?}}
}

# Pop octet from list
popo() {
	echo ${1%% [0-7][0-7][0-7]}
}

o1_to_bin() {
	oct="$1"	# positional params can't be reassigned
	idx=1 		# digit index (o_{1,2,3})
	while test "$oct"; do
		dig=`popc $oct`
		test $idx -eq 1 || echo -n "$(($dig >> 2 & 0x1))" # skip msb of o1
		echo -n "$(($dig >> 1 & 0x1))"
		echo -n "$(($dig & 0x1))"
		oct=${oct#?}
		idx=$((idx+1))
	done
}

#for byte in `od -An -to1 "$FNAME"`; do

bytes=`od -An -to1 "$FNAME"`	# read
bytes=${bytes##[\n\t ]}		# trim
bitpool=""			# leftover bits from last 6-bit word construction
words=""			# Values in the range [0-63], encoded in binary
while test ${#bytes} -gt 0 -o "$bitpool"; do
	octetBits=""
	word=0
	idx=0

	# construct a 6-bit word
	while test $idx -lt 6; do
		if test "$bitpool"; then
			# empty out pool
			pBit=`popc $bitpool`
			bitpool=${bitpool#[ \t\n]}	# remove blank if any
			bitpool=${bitpool#[01]}		# shift
			word=$((word << 1 | $pBit))
		elif test "$octetBits" -o ${#bytes} -gt 0; then
			if test -z "${octetBits}"; then
				octetBits=`popo $bytes`		# extract octet
				bytes=${bytes#$octetBits}	# shift list
				bytes=${bytes##[ \t\n]}		# remove blanks
				octetBits=`o1_to_bin $octetBits` # convert to bits
			fi
			pBit=`popc $octetBits`
			octetBits=${octetBits#[ \t\n]}
			octetBits=${octetBits#[01]}
			word=$((word << 1 | $pBit))
		else
			# no more bits, append with zeroes to form a 6-bit word
			word=$((word << 1))
		fi
		idx=$((idx+1))
	done

	bitpool="$bitpool$octetBits"		# save leftovers
	words="$words\\`printf %o $word`"	# save word
done

words=`echo -n $words | tr "\
\0\01\02\03\04\05\06\07\010\011\012\013\014\015\016\017\020\
\021\022\023\024\025\026\027\030\031\032\033\034\035\036\037\040\
\041\042\043\044\045\046\047\050\051\052\053\054\055\056\057\060\
\061\062\063\064\065\066\067\070\071\072\073\074\075\076\077" \
"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"`

# Add any padding words
while test $((${#words} % 4)) -ne 0; do
	words="$words="
done

echo $words

exit 0
