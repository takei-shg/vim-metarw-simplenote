if !exists('s:token')
  let s:email = ''
  let s:token = ''
  let s:titles = {}
  let s:tags_map = {}
  let s:modifydates = {}
endif

let s:AUTH_URL = 'https://simple-note.appspot.com/api/login'
let s:DATA_URL = 'https://simple-note.appspot.com/api2/data/'
let s:INDX_URL = 'https://simple-note.appspot.com/api2/index?'
let s:NOTE_FETCH_LENGTH = 20

function! metarw#sn#complete(arglead, cmdline, cursorpos)
  if len(s:authorization())
    return [['auth error'], 'sn:', '']
  endif
  let url = printf(s:INDX_URL . 'auth=%s&email=%s&length=%d', s:token, s:email, s:NOTE_FETCH_LENGTH)
  let res = webapi#http#get(url)
  let g:sn_complete_notelistres = res
  let nodes = webapi#json#decode(iconv(res.content, 'utf-8', &encoding))
  let candidate = []
  for node in nodes.data
    if !node.deleted
      if !has_key(s:titles, node.key)
        let url = printf(s:DATA_URL . '%s?auth=%s&email=%s', node.key, s:token, s:email)
        let res = webapi#http#get(url)
        let g:sn_complete_noteres = res
        let res_content = webapi#json#decode(iconv(res.content, 'utf-8', &encoding))
        if res.status =~ '^2'
          let lines = split(iconv(res_content.content, 'utf-8', &encoding), "\n")
          let s:titles[node.key] = len(lines) > 0 ? lines[0] : ''

          let taglist = map(res_content.tags, iconv('v:val', 'utf-8', &encoding))
          let s:tags_map[node.key] = join(taglist, ',')

          let modifydate = iconv(res_content.modifydate, 'utf-8', &encoding)
          let s:modifydates[node.key] = modifydate

        else
          echoerr printf('cannot get content for the key: %s \n', node.key)
        endif
      endif
      call add(candidate, {
      \ "modifydate" : s:modifydates[node.key],
      \ "tags" : '[' . s:tags_map[node.key] . ']',
      \ "title" : escape(s:titles[node.key], ' \/#%'),
      \ "key" : node.key
      \})
    endif
  endfor
  return [candidate, 'sn:', '']
"   return [s:mocklist(), 'sn:', '']
endfunction

function! s:mocklist()
  let candidates = []
  for e in ['agtzaW1wbGUtbm90ZXIqCxIETm90ZSIgMDFiYTFiZjdmMmU0NDIwZmEyYjFmOWJmZjdjMTk2Y2UM', 'aaa', 'bbb']
    let title = 'title is on 7/23'
    call add(candidates, printf('sn:%s:%s', escape(title, ' \/#%'), e))
  endfor
  return candidates
endfunction

function! metarw#sn#read(fakepath)
  " fakepath = sn: . {note_key}
  let l = split(a:fakepath, ':')
  if len(l) < 2
    return ['error', printf('Unexpected fakepath: %s', string(a:fakepath))]
  endif

  let note_key = l[1]

  if len(s:authorization())
    return ['error', 'error in authorization']
  endif

  let url = printf('https://simple-note.appspot.com/api2/data/%s?auth=%s&email=%s', note_key, s:token, webapi#http#encodeURI(s:email))
  let res = webapi#http#get(url)
  let content = webapi#json#decode(res.content).content

  if res.status =~ '^2'
    setlocal noswapfile
    put = iconv(content, 'utf-8', &encoding)
    let b:sn_key = note_key
    return ['done', '']
  endif
  return ['error', res.header[0]]
endfunction

function! metarw#sn#write(fakepath, line1, line2, append_p)
  let g:sn_write_fakepath = string(a:fakepath)
  let g:sn_write_append_p = string(a:append_p)
  let l = split(a:fakepath, ':')
  if len(l) < 2
    return ['error', printf('Unexpected fakepath: %s', string(a:fakepath))]
  endif

  let note_key = l[1]
  let g:sn_note_key = note_key

  if len(s:authorization())
    return ['error', 'error in authorization']
  endif
"   if len(note_key) > 0 && line('$') == 1 && getline(1) == ''
"     let url = printf('https://simple-note.appspot.com/api/delete?key=%s&auth=%s&email=%s', note_key, s:token, s:email)
"     let res = webapi#http#get(url)
"     if res.status =~ '^2'
"       echomsg 'deleted'
"       return ['done', '']
"     endif
"   endif
  if len(note_key) > 0
    " update with key
    let url = printf('https://simple-note.appspot.com/api2/data/%s?auth=%s&email=%s', note_key, s:token, webapi#http#encodeURI(s:email))
  else
    " create new note
    let url = printf('https://simple-note.appspot.com/api2/data?auth=%s&email=%s', s:token, s:email)
  endif
  let g:sn_update_url = url
  let res = webapi#http#post(url,
  \  webapi#http#encodeURI(iconv(webapi#json#encode({
  \    'content': join(getline(a:line1, a:line2), "\n"),
  \  }),
  \ 'utf-8',
  \ &encoding))
  \)
  if res.status =~ '^2'
    if len(note_key) == 0
      let key = res.content
      silent! exec 'file '.printf('sn:%s', escape(key, ' \/#%'))
      set nomodified
    endif
    return ['done', '']
  endif
  return ['error', 'status code : ' . res.status]
endfunction

function! s:authorization()
  if len(s:token) > 0
    return ''
  endif
  let s:email = input('email:')
  let password = inputsecret('password:')
  let creds = webapi#base64#b64encode(printf('email=%s&password=%s', s:email, password))
  let res = webapi#http#post(s:AUTH_URL, creds)
  if res.status =~ '^2'
    let s:token = res.content
    return ''
  endif
  return 'failed to authenticate'
endfunction

