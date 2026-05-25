from pathlib import Path
p=Path(r'c:/Users/gurni/Dev/Flutter/Musee-client/lib/features/user_playlists/presentation/pages/user_playlist_page.dart')
s=p.read_text()
pairs={'(':')','{':'}','[':']'}
stack=[]
for i,ch in enumerate(s,1):
    if ch in '({[':
        stack.append((ch,i))
    elif ch in ')}]':
        if not stack:
            print('Unmatched closing',ch,'at',i)
            break
        o,pos=stack.pop()
        if pairs[o]!=ch:
            print('Mismatched',o,'at',pos,'vs',ch,'at',i)
            open_pos=pos
            close_pos=i
            break
else:
    if stack:
        print('Unclosed at end, top:',stack[-1])
    else:
        print('All good')

if 'open_pos' in globals():
    def pos_to_linecol(pos):
        before=s[:pos]
        line=before.count('\n')+1
        col=pos-before.rfind('\n')
        return line,col
    print('open at',pos_to_linecol(open_pos))
    print('close at',pos_to_linecol(close_pos))
    lines=s.splitlines()
    line,col=pos_to_linecol(open_pos)
    start=max(0,line-5)
    end=min(len(lines),line+5)
    print('\n'.join(f"{i+1:5}: {lines[i]}" for i in range(start,end)))
