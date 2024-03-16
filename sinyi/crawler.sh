#!/bin/sh

log_msg_error()
{
	echo "ERROR: $1"
}

log_msg_warn()
{
	echo "WARN: $1"
}

parse_page()
{
	[ "$#" -lt 1 ] && return 1
	local path_html="$1"
	local begin=""
	local end=""
	local list=""
	local id=""
	local is_show=""
	local ret=""

	if [ ! -f "${path_html}" ]; then
		log_msg_error "Failed to find ${path_html}"
		return 1
	fi

	if ! begin=$(grep -oh "list\":\[{\"houseNo\":\"[ 0-9a-zA-Z]*\",\"name\"" "${path_html}"); then
		echo ""
		return 0
	fi
	begin=$(echo "${begin}" | cut -d'"' -f5)

	if ! end=$(grep -oh "recommendList\":\[{\"houseNo\":\"[ 0-9a-zA-Z]*\",\"name\"" "${path_html}"); then
		log_msg_error "Failed to grep end in ${path_html}"
		return 1
	fi
	end=$(echo "${end}" | cut -d'"' -f5)

	if ! list=$(grep -oh "houseNo\":\"[ 0-9a-zA-Z]*\",\"name\"" "${path_html}"); then
		log_msg_error "Failed to grep list in ${path_html}"
		return 1
	fi
	list=$(echo "${list}" | cut -d'"' -f3)

	is_show=0
	for id in ${list}; do
		if [ "${id}" = "${begin}" ]; then
			is_show=1
		fi
		if [ "${id}" = "${end}" ]; then
			is_show=0
		fi
		if [ "${is_show}" -ge 1 ]; then
			ret="${ret} ${id}"
		fi
	done

	echo "${ret}"
	return 0
}

dump_obj()
{
	[ "$#" -lt 3 ] && return 1
	local path_html="$1"
	shift
	local list_id="$1"
	shift
	local path_json="$1"
	local id=""
	local msg=""

	for id in ${list_id}; do
			if ! msg=$(grep -oh "{\"houseNo\":\"${id}\",\"name\"[^}]*}" "${path_html}"); then
				log_msg_error "Failed to grep json obj for ${id} in ${path_html}"
				return 1
			fi
			if [ -e "${path_json}" ]; then
				echo "," >> "${path_json}"
			else
				echo "[" >> "${path_json}"
			fi
			echo "${msg}" >> "${path_json}"
	done

	return 0
}

crawler_curl()
{
	[ "$#" -lt 1 ] && return 1
	local url="$1"
	local ua=""
	ua="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/109.0.0.0 Safari/537.36"
	curl -X GET -H "User-Agent: ${ua}" "${url}"
}

crawler_curl_e()
{
	[ "$#" -lt 1 ] && return 1
	local url="$1"
	local retry=""
	for retry in $(seq 1 5); do
		if crawler_curl "${url}"; then
			return 0
		fi
		log_msg_warn "Failed to curl ${url}"
	done
	log_msg_error "Failed to curl ${url}"
	return 1
}

crawler()
{
	[ "$#" -lt 3 ] && return 1
	local dir="$1"
	shift
	local path_json="$1"
	shift
	local args="$1"
	local a1=""
	local a2=""
	local a3=""
	local a4=""
	local page="1"
	local path_html=""
	local list_id=""

	a1=$(echo "${args}" | cut -d"_" -f1)
	a2=$(echo "${args}" | cut -d"_" -f2)
	a3=$(echo "${args}" | cut -d"_" -f3)
	a4=$(echo "${args}" | cut -d"_" -f4)

	while true; do
		path_html="${dir}/sinyi_${args}_${page}.html"
		if ! crawler_curl_e "https://www.sinyi.com.tw/buy/list/${a1}/${a2}/${a3}/${a4}/default-desc/${page}" > "${path_html}"; then

			return 1
		fi

		if ! list_id=$(parse_page "${path_html}"); then
			echo "${list_id}"
			return 1
		fi

		if [ -z "${list_id}" ]; then
			break
		fi

		if ! dump_obj "${path_html}" "${list_id}" "${path_json}"; then
			return 1
		fi

		page=$(expr "${page}" + 1)
		sleep 60
	done

	return 0
}

main()
{
	local datetime="$1"
	local dir=""
	local path_json=""

	dir="/var/services/homes/admin/EstateAnalysis"

	if [ -z "${datetime}" ]; then
		datetime=$(date "+%Y%m%d")
	fi

	dir="${dir}/results/${datetime}"

	if [ -e "${dir}" ]; then
		log_msg_error "Failed create ${dir} because of duplicate"
		return 1
	fi

	if ! mkdir -p "${dir}"; then
		log_msg_error "Failed create ${dir}"
		return 1
	fi

	path_json="${dir}/sinyi.json"

	args="flat-apartment-dalou-huaxia-type_noparking_Taipei-city_100-103-104-105-108-114-115-116-zip"
	if ! crawler "${dir}" "${path_json}" "${args}"; then
		return 1
	fi

	args="flat-apartment-dalou-huaxia-type_noparking_NewTaipei-city_220-234-235-zip"
	if ! crawler "${dir}" "${path_json}" "${args}"; then
		return 1
	fi

	if [ ! -e "${path_json}" ]; then
		echo "[" >> "${path_json}"
	fi
	echo "]" >> "${path_json}"

	return 0
}

main
