if exists("g:loaded_simplenote_service")
  finish
endif
let g:loaded_simplenote_service = 1

" Variables "{{{1
let s:FALSE = 0
let s:TRUE = !s:FALSE


if !exists('s:token')
  let s:email = ''
  let s:token = ''
  let s:titles = {}
  let s:tags_map = {}
  let s:modifydates = {}
endif

let s:AUTH_URL = 'https://simple-note.appspot.com/api/login'
let s:DATA_URL = 'https://simple-note.appspot.com/api2/data/'
let s:NEW_URL = 'https://simple-note.appspot.com/api2/data'
let s:INDX_URL = 'https://simple-note.appspot.com/api2/index?'
let s:NOTE_FETCH_LENGTH = 20

" note_key :: String
" modifydate :: String
function! metarw#service#simplenote#check_modified(note_key, modifydate)

  if len(s:token) == 0
    return [['auth error'], 'sn:', '']
  endif

  let url = printf(s:DATA_URL . '%s?auth=%s&email=%s', a:note_key, s:token, s:email)
  let res = webapi#http#get(url)
  let g:metarw_service_sn_edit_tag_noteres = res " TODO : Debug
  if res.status =~ '^2'
    let res_content = webapi#json#decode(iconv(res.content, 'utf-8', &encoding))
    " FIXME cofirm we can use modifydate to check tag updated
    let modifydate = iconv(res_content.modifydate, 'utf-8', &encoding)
    if modifydate != a:modifydate
      return [['note is updated'], 'sn:', '']
    endif

  else
    echoerr printf('cannot get content for the key: %s \n', node.key)
  endif
endfunction

function! metarw#service#simplenote#get_notelist()
  if len(s:token) == 0
    let result = metarw#service#simplenote#authorization()
    if result == s:FALSE
      return {
      \ 'result' : s:FALSE,
      \ 'message' : 'error in authorization',
      \ }
    endif
  endif

  let url = printf(s:INDX_URL . 'auth=%s&email=%s&length=%d',
  \  s:token,
  \  s:email,
  \  s:NOTE_FETCH_LENGTH)
  let res = webapi#http#get(url)

  if res.status !~ '^2'
    echoerr printf('cannot get note list, response header: %s - %s', res.status, res.message)
    return {
    \ 'result' : s:FALSE,
    \ 'message' : printf('%s : %s', res.status, res.message) ,
    \ }
  endif
  let g:sn_complete_notelistres = res " TODO : Debug
  let nodes = webapi#json#decode(iconv(res.content, 'utf-8', &encoding))
  return {
  \ 'result' : s:TRUE,
  \ 'data' : nodes,
  \ }
endfunction

" note_key :: String
function! metarw#service#simplenote#read_note(note_key)
  " FIXME : if the authorization is not finished, it doesn't call auth
  if len(s:token) == 0
    let result = metarw#service#simplenote#authorization()
    if result == s:FALSE
      return {
      \ 'result' : s:FALSE,
      \ 'message' : 'error in authorization',
      \ }
    endif
  endif
  let g:metarw_service_read_note_key = a:note_key " TODO : Debug

  let url = printf(s:DATA_URL . '%s?auth=%s&email=%s', a:note_key, s:token, webapi#http#encodeURI(s:email))
  let g:metarw_service_read_url = url " TODO : Debug
  let res = webapi#http#get(url)
  let g:metarw_service_read_res = res " TODO : Debug

  if res.status =~ '^2'
    let content = webapi#json#decode(iconv(res.content, 'utf-8', &encoding))
    return {
    \ 'result' : s:TRUE,
    \ 'data' : content,
    \ }
  else
    echoerr printf('cannot get content for the key: %s, response header: %s', a:note_key, res.status)
    return {
      \ 'result' : s:FALSE,
      \ 'message' : printf('%s : %s', res.status, res.message) ,
      \ }
  endif
endfunction

" note_key :: String
" newtags :: [String]
function! metarw#service#simplenote#edit_tag(note_key, newtags)"{{{
  if len(s:token) == 0
    let result = metarw#service#simplenote#authorization()
    if result == s:FALSE
      return {
      \ 'result' : s:FALSE,
      \ 'message' : 'error in authorization',
      \ }
    endif
  endif

  let update_url = printf(s:DATA_URL . '%s?auth=%s&email=%s', a:note_key, s:token, webapi#http#encodeURI(s:email))
  let res = webapi#http#post(update_url,
  \  webapi#http#encodeURI(iconv(webapi#json#encode({
  \    'tags': a:newtags,
  \  }),
  \ 'utf-8',
  \ &encoding))
  \)
  if res.status =~ '^2'
    return s:TRUE
  else
    echoerr printf('error in update tags. note_key: %s, response header: %s. ', a:note_key, res.status)
    return s:FALSE
  endif
endfunction"}}}

" note_key :: String
" content :: String
function! metarw#service#simplenote#update_note(note_key, content)"{{{
  if len(s:token) == 0
    let result = metarw#service#simplenote#authorization()
    if result == s:FALSE
      return {
      \ 'result' : s:FALSE,
      \ 'message' : 'error in authorization',
      \ }
    endif
  endif
  let update_url = printf(s:DATA_URL . '%s?auth=%s&email=%s', a:note_key, s:token, webapi#http#encodeURI(s:email))
  let res = webapi#http#post(update_url,
  \  webapi#http#encodeURI(iconv(webapi#json#encode({
  \    'content': a:content,
  \  }),
  \ 'utf-8',
  \ &encoding))
  \)
  if res.status =~ '^2'
    return s:TRUE
  else
    echoerr printf('error in update note. note_key: %s, response header: %s. ', a:note_key, res.status)
    return s:FALSE
  endif
endfunction"}}}

function! metarw#service#simplenote#create_note()"{{{
  if len(s:token) == 0
    let result = metarw#service#simplenote#authorization()
    if result == s:FALSE
      return {
      \ 'result' : s:FALSE,
      \ 'message' : 'error in authorization',
      \ }
    endif
  endif
  let url = printf(s:NEW_URL . '?auth=%s&email=%s', s:token, webapi#http#encodeURI(s:email))
  let res = webapi#http#post(url,
  \  webapi#http#encodeURI(iconv(webapi#json#encode({
  \    'content': '',
  \  }),
  \ 'utf-8',
  \ &encoding))
  \)
  if res.status =~ '^2'
    let content = webapi#json#decode(iconv(res.content, 'utf-8', &encoding))
    return {
    \ 'result' : s:TRUE,
    \ 'key' : content.key,
    \ }
  else
    echoerr printf('error in create new note. response header: %s. ', res.status)
    return {
    \ 'result' : s:FALSE,
    \ 'message' : printf('%s : %s', res.status, res.message) ,
    \ }
  endif
endfunction"}}}

" content :: String
function! metarw#service#simplenote#create_note_w_content(content)"{{{
  if len(s:token) == 0
    let result = metarw#service#simplenote#authorization()
    if result == s:FALSE
      return {
      \ 'result' : s:FALSE,
      \ 'message' : 'error in authorization',
      \ }
    endif
  endif
  let url = printf(s:NEW_URL . '?auth=%s&email=%s', s:token, webapi#http#encodeURI(s:email))
  let res = webapi#http#post(url,
  \  webapi#http#encodeURI(iconv(webapi#json#encode({
  \    'content': a:content,
  \  }),
  \ 'utf-8',
  \ &encoding))
  \)
  if res.status =~ '^2'
    let content = webapi#json#decode(iconv(res.content, 'utf-8', &encoding))
    return {
    \ 'result' : s:TRUE,
    \ 'key' : content.key,
    \ }
  else
    echoerr printf('error in create new note. response header: %s. ', res.status)
    return {
    \ 'result' : s:FALSE,
    \ 'message' : printf('%s : %s', res.status, res.message) ,
    \ }
  endif
endfunction"}}}

function! metarw#service#simplenote#authorization()"{{{
  if len(s:token) > 0
    return s:TRUE
  endif
  " let s:email = input('email:')
  " FIXME: hard coded email address
  let s:email = 'takei.shg@gmail.com'
  let password = inputsecret('password:')
  let creds = webapi#base64#b64encode(printf('email=%s&password=%s', s:email, password))
  let res = webapi#http#post(s:AUTH_URL, creds)
  if res.status =~ '^2'
    let s:token = res.content
    return s:TRUE
  endif
  return s:FALSE
endfunction"}}}

" local functions {{{
" }}}

