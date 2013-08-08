if !exists('s:token')
  let s:email = ''
  let s:token = ''
  let s:titles = {}
endif

function! metarw#sn#complete(arglead, cmdline, cursorpos)
  if len(s:authorization())
    return [['auth error'], 'sn:', '']
  endif
  let url = printf('https://simple-note.appspot.com/api/index?auth=%s&email=%s', s:token, s:email)
  let res = webapi#http#get(url)
  let nodes = webapi#json#decode(iconv(res.content, 'utf-8', &encoding))
  let candidate = []
  for node in nodes
    if !node.deleted
      if !has_key(s:titles, node.key)
        let url = printf('https://simple-note.appspot.com/api/note?key=%s&auth=%s&email=%s', node.key, s:token, s:email)
        let res = webapi#http#get(url)
        if res.status =~ '^2'
          let lines = split(iconv(res.content, 'utf-8', &encoding), "\n")
          let s:titles[node.key] = len(lines) > 0 ? lines[0] : ''
        else
          echoerr printf('cannot get content for the key: %s \n', node.key)
        endif
      endif
      call add(candidate, printf('sn:%s:%s', escape(node.key, ' \/#%'), escape(s:titles[node.key], ' \/#%')))
    endif
  endfor
  return [candidate, 'sn:', '']
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
  let url = printf('https://simple-note.appspot.com/api/note?key=%s&auth=%s&email=%s', note_key, s:token, s:email)
  let res = webapi#http#get(url)
  if res.status =~ '^2'
    setlocal noswapfile
    put = iconv(res.content, 'utf-8', &encoding)
    let b:sn_key = note_key
    return ['done', '']
  endif
  return ['error', res.header[0]]
endfunction

function! metarw#sn#write(fakepath, line1, line2, append_p)
  let l = split(a:fakepath, ':', 1)
  if len(l) < 2
    return ['error', printf('Unexpected fakepath: %s', string(a:fakepath))]
  endif
  let err = s:authorization()
  if len(err)
    return ['error', err)
  endif
  if len(l[1]) > 0 && line('$') == 1 && getline(1) == ''
    let url = printf('https://simple-note.appspot.com/api/delete?key=%s&auth=%s&email=%s', l[1], s:token, s:email)
    let res = webapi#http#get(url)
    if res.status =~ '^2'
      echomsg 'deleted'
      return ['done', '']
    endif
  endif
    if len(l[1]) > 0
      let url = printf('https://simple-note.appspot.com/api/note?key=%s&auth=%s&email=%s', l[1], s:token, s:email)
    else
      let url = printf('https://simple-note.appspot.com/api/note?auth=%s&email=%s', s:token, s:email)
    endif
    let res = webapi#http#post(url, webapi#base64#b64encode(iconv(join(getline(a:line1, a:line2), "\n"), &encoding, 'utf-8')))
    if res.status =~ '^2'
      if len(l[1]) == 0
        let key = res.content
        silent! exec 'file '.printf('sn:%s', escape(key, ' \/#%'))
        set nomodified
      endif
      return ['done', '']
    endif
  endif
  return ['error', res.header[0]]
endfunction

function! s:authorization()
  if len(s:token) > 0
    return ''
  endif
  let s:email = input('email:')
  let password = inputsecret('password:')
  let creds = webapi#base64#b64encode(printf('email=%s&password=%s', s:email, password))
  let res = webapi#http#post('https://simple-note.appspot.com/api/login', creds)
  if res.status =~ '^2'
    let s:token = res.content
    return ''
  endif
  return 'failed to authenticate'
endfunction

