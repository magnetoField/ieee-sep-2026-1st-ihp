from random import Random
MASK=(1<<32)-1
Z=0xfc2ce51207a635db

def rol(x,n): return ((x<<n)|(x>>(32-n)))&MASK
def ror(x,n): return ((x>>n)|(x<<(32-n)))&MASK

def ref(p,k):
    keys=[(k>>(32*i))&MASK for i in range(4)]
    for i in range(4,44):
        tmp=ror(keys[i-1],3)^keys[i-3]
        keys.append((0xfffffffc^keys[i-4]^tmp^ror(tmp,1)^((Z>>(i-4))&1))&MASK)
    x,y=p>>32,p&MASK
    trace=[]
    for i in range(44):
        x,y=((rol(x,1)&rol(x,8))^rol(x,2)^y^keys[i])&MASK,x
        trace.append((x,y))
    return (x<<32)|y,keys,trace

def bitserial(p,k):
    a,b=p>>32,p&MASK
    ks=[(k>>(32*i))&MASK for i in range(4)]
    trace=[]
    for r in range(44):
        for i in range(32):
            x,y=(a,b) if r%2==0 else (b,a)
            nb=((x>>31)&1)&((x>>24)&1)
            nb^=((x>>30)&1)^(y&1)^(ks[0]&1)
            xn=ror(x,1); yn=((nb<<31)|(y>>1))&MASK
            a,b=(xn,yn) if r%2==0 else (yn,xn)
            if r<40:
                nk=(ks[0]&1)^((ks[3]>>3)&1)^((ks[3]>>4)&1)^(ks[1]&1)^((ks[1]>>1)&1)^int(i>=2)^(int(i==0)*((Z>>r)&1))
            else:
                nk=0
            nxt=[(ks[0]>>1)|(nk<<31)]+[ror(w,1) for w in ks[1:]]
            ks=nxt if i<31 else nxt[1:]+nxt[:1]
        trace.append((b,a) if r%2==0 else (a,b))
    assert ks==[0,0,0,0]
    return (a<<32)|b, trace

katp=0x656b696c20646e75
katk=0x1b1a1918131211100b0a090803020100
katc=0x44c8fc20b9dfa07a
assert ref(katp,katk)[0]==katc
assert bitserial(katp,katk)[0]==katc
rng=Random(0x52554d43)
for j in range(1024):
    p=rng.getrandbits(64); k=rng.getrandbits(128)
    c,rk,tr=ref(p,k); cb,tb=bitserial(p,k)
    assert c==cb and tr==tb, j
print('Published SIMON64/128 KAT: PASS')
print('Proposed bit-serial arithmetic vs word reference: 1024 random pairs, all 44 round states: PASS')
print('These are Python arithmetic checks only; no RTL, synthesis, layout or hardware has been tested.')
print('Core round cycles:',44*32)
print('Demo bad-key response to KAT challenge:', format(ref(katp,0xf0e1d2c3b4a5968778695a4b3c2d1e0f)[0],'016x'))
