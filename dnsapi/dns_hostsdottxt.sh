#!/usr/bin/env sh

#HDT_Token="xxxx"
HDT_Api="http://hostsdottxt.net/api/v1"

########  Public functions #####################
#Usage: add  _acme-challenge.www.domain.com   "XKrxpRBosdIKFzxW_CT3KLZNf6q0HG9i01zxXp5CPBs"
dns_hostsdottxt_add() {
  fulldomain=$1
  txtvalue=$2

  HDT_Token="${HDT_Token:-$(_readaccountconf_mutable HDT_Token)}"

  if [ "$HDT_Token" ]; then
    _savedomainconf HDT_Token "$HDT_Token"
  else
    _err "no HDT_Token found"
    return 1
  fi

  _debug "First detect the root zone"
  if ! _get_root "$fulldomain"; then
    _err "invalid domain"
    return 1
  fi
  _debug _root "$_root"

  # For wildcard cert, the main root domain and the wildcard domain have the same txt subdomain name, so
  # we can not use updating anymore.
  #  count=$(printf "%s\n" "$response" | _egrep_o "\"count\":[^,]*" | cut -d : -f 2)
  #  _debug count "$count"
  #  if [ "$count" = "0" ]; then
  _info "Adding record"
  if _hdt_rest PUT "zones/$_root" "{\"type\":\"TXT\",\"name\":\"$fulldomain.\",\"content\":\"$txtvalue\",\"ttl\":60}"; then
    if _contains "$response" "$txtvalue"; then
      _info "Added, OK"
      return 0
    elif _contains "$response" "The record already exists"; then
      _info "Already exists, OK"
      return 0
    else
      _err "Add txt record error."
      return 1
    fi
  fi
  _err "Add txt record error."
  return 1

}

# #fulldomain txtvalue
# dns_cf_rm() {
#   fulldomain=$1
#   txtvalue=$2

#   HDT_Token="${HDT_Token:-$(_readaccountconf_mutable HDT_Token)}"
#   CF_Account_ID="${CF_Account_ID:-$(_readaccountconf_mutable CF_Account_ID)}"
#   CF_Zone_ID="${CF_Zone_ID:-$(_readaccountconf_mutable CF_Zone_ID)}"
#   CF_Key="${CF_Key:-$(_readaccountconf_mutable CF_Key)}"
#   CF_Email="${CF_Email:-$(_readaccountconf_mutable CF_Email)}"

#   _debug "First detect the root zone"
#   if ! _get_root "$fulldomain"; then
#     _err "invalid domain"
#     return 1
#   fi
#   _debug _domain_id "$_domain_id"
#   _debug _sub_domain "$_sub_domain"
#   _debug _domain "$_domain"

#   _debug "Getting txt records"
#   _HDT_rest GET "zones/${_domain_id}/dns_records?type=TXT&name=$fulldomain&content=$txtvalue"

#   if ! echo "$response" | tr -d " " | grep \"success\":true >/dev/null; then
#     _err "Error: $response"
#     return 1
#   fi

#   count=$(echo "$response" | _egrep_o "\"count\": *[^,]*" | cut -d : -f 2 | tr -d " ")
#   _debug count "$count"
#   if [ "$count" = "0" ]; then
#     _info "Don't need to remove."
#   else
#     record_id=$(echo "$response" | _egrep_o "\"id\": *\"[^\"]*\"" | cut -d : -f 2 | tr -d \" | _head_n 1 | tr -d " ")
#     _debug "record_id" "$record_id"
#     if [ -z "$record_id" ]; then
#       _err "Can not get record id to remove."
#       return 1
#     fi
#     if ! _HDT_rest DELETE "zones/$_domain_id/dns_records/$record_id"; then
#       _err "Delete record error."
#       return 1
#     fi
#     echo "$response" | tr -d " " | grep \"success\":true >/dev/null
#   fi

# }

####################  Private functions below ##################################
#_acme-challenge.www.domain.com
#returns
# _sub_domain=_acme-challenge.www
# _domain=domain.com
# _domain_id=sdjkglgdfewsdfg
_get_root() {
  domain=$1
  _debug "$domain"

  export _H1="Authorization: Bearer $(echo "$HDT_Token" | tr -d '"')"
  response=$(_get "$HDT_Api/zones/root?domain=$domain")

  if [ "$?" != "0" ]; then
    _err "error $ep"
    return 1
  fi

  _debug "$response"

  _root="$response"
  return 0
}

_hdt_rest() {
  method=$1
  endpoint="$2"
  data="$3"
  _debug "$HDT_Api/$endpoint"

  token_trimmed=$(echo "$HDT_Token" | tr -d '"')

  export _H1="Content-Type: application/json"
  export _H2="Authorization: Bearer $token_trimmed"

  if [ "$method" != "GET" ]; then
    _debug data "$data"
    response="$(_post "$data" "$HDT_Api/$endpoint" "" "$method")"
  else
    response="$(_get "$HDT_Api/$endpoint")"
  fi

  if [ "$?" != "0" ]; then
    _err "error $endpoint"
    return 1
  fi
  _debug2 response "$response"
  return 0
}
