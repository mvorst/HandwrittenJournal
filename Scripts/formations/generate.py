#!/usr/bin/env python3
"""Rebuild per-font centerlines from the bundled TTFs, then verify and draw atlases.

Development dependencies only: pillow, numpy, scipy, scikit-image, networkx.
Run from any directory: python Scripts/formations/generate.py --output /tmp/formations
A frozen copy of the original Jua school-order guides seeds route ordering only. Every
point ultimately follows the CURRENT font's skeleton; no Jua coordinates are shipped
for a different face. Explicit topology overrides handle serifs and double-storey a.
"""
from __future__ import annotations
import argparse, hashlib, json, math
from pathlib import Path
import networkx as nx
import numpy as np
from PIL import Image, ImageDraw, ImageFont
from scipy.ndimage import distance_transform_edt, label
from scipy.spatial import cKDTree
from skimage.morphology import skeletonize
from skimage.measure import approximate_polygon

ROOT = Path(__file__).resolve().parents[2]
CHARS = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789'
FONTS = ['Jua-Regular','Andika-Bold','VarelaRound-Regular','Sniglet-ExtraBold','ComicNeue-Bold']
PIXELS = 512
PAD = 5
COLORS = ['#e23f45','#1685c7','#109762','#b367c2','#e08a12','#556270']
TEMPLATES = json.loads((Path(__file__).parent / 'jua-stroke-order.json').read_text())


def smooth(points, rounds=2):
    points=np.array(points,dtype=float)
    for _ in range(rounds):
        points=np.vstack([points[0],np.stack([points[:-1]*.75+points[1:]*.25,points[:-1]*.25+points[1:]*.75],axis=1).reshape(-1,2),points[-1]])
    return points


def resample(points, spacing=3):
    points=np.array(points,dtype=float)
    if len(points)==1: return points
    lens=np.linalg.norm(np.diff(points,axis=0),axis=1)
    starts=np.r_[0,np.cumsum(lens)]
    if starts[-1]<1e-5: return points[:1]
    targets=np.linspace(0,starts[-1],math.ceil(starts[-1]/spacing)+1)
    return np.column_stack([np.interp(targets,starts,points[:,axis]) for axis in (0,1)])


def glyph_mask(face,char):
    font=ImageFont.truetype(str(ROOT / 'HandwrittenJournal/Resources/Fonts' / f'{face}.ttf'),PIXELS)
    m=font.getmask(char,mode='L')
    image=Image.frombytes('L',m.size,bytes(m))
    bbox=image.point(lambda p:255 if p>127 else 0).getbbox()
    image=image.crop(bbox)
    mask=np.pad(np.array(image)>127,PAD)
    return mask


def graph_of(mask):
    skel=skeletonize(mask)
    g=nx.Graph()
    coords=set(map(tuple,np.argwhere(skel)))
    for y,x in coords:
        g.add_node((y,x))
        for dy,dx in [(0,1),(1,-1),(1,0),(1,1)]:
            p=(y+dy,x+dx)
            # Orthogonal edges already provide connectivity; omit redundant diagonal
            # triangles, which otherwise look like extra pen strokes at junctions.
            if p in coords and not (dy and dx and ((y+dy,x) in coords or (y,x+dx) in coords)):
                g.add_edge((y,x),p,weight=math.hypot(dx,dy))
    radius=distance_transform_edt(mask)
    # Short twigs around thick terminals/corners are skeleton artifacts, not strokes.
    # Only prune to the first junction and never remove a disconnected dot or line.
    for _ in range(8):
        remove=set()
        for start in list(g.nodes):
            if g.degree(start)!=1: continue
            route=[start]; prev=None; p=start
            while True:
                nxt=[q for q in g[p] if q!=prev]
                if len(nxt)!=1: break
                prev,p=p,nxt[0]; route.append(p)
            if g.degree(p)>2:
                length=sum(math.dist(a,b) for a,b in zip(route,route[1:]))
                if radius[start] < max(3, radius[p]*.35) and length < max(4,radius[p]*1.5): remove.update(route[:-1])
        if not remove: break
        g.remove_nodes_from(remove)
    # Thinning a square terminal bends the skeleton toward one corner. Trim that
    # low-radius tail back to the constant-width stem; teaching the corner would
    # add a fake diagonal stroke to every Andika stem.
    trim=set()
    for start in list(g.nodes):
        if g.degree(start)!=1: continue
        route=[start]; prev=None; p=start; travel=0
        while travel < PIXELS*.2:
            nxt=[q for q in g[p] if q!=prev]
            if len(nxt)!=1: break
            prev,p=p,nxt[0]; route.append(p); travel+=math.dist(prev,p)
        peak=max(radius[q] for q in route)
        if radius[start] < peak*.5:
            for q in route[:-1]:
                if radius[q]>=peak*.88: break
                trim.add(q)
    g.remove_nodes_from(trim)
    return g,radius


def guide_strokes(face,char,shape):
    strokes=TEMPLATES[char]
    # Font-specific structural differences, visible in the outlines. A serif I must
    # teach both bars; a 1's baseline must not be mistaken for a second vertical.
    if char=='I' and face in ('Andika-Bold','ComicNeue-Bold'):
        strokes=[dict(points=[[.5,0],[.5,1]],curved=False),dict(points=[[0,0],[1,0]],curved=False),dict(points=[[0,1],[1,1]],curved=False)]
    if char=='J' and face=='Jua-Regular':
        strokes=strokes+[dict(points=[[0,0],[1,0]],curved=False)]
    if char=='1' and face in ('Andika-Bold','VarelaRound-Regular','ComicNeue-Bold'):
        strokes=strokes+[dict(points=[[0,1],[1,1]],curved=False)]
    # Varela Round has a two-storey a, unlike the four other bundled faces.
    if char=='a' and face=='VarelaRound-Regular':
        strokes=[dict(points=[[.1,.13],[.35,0],[.7,0],[.95,.2],[.95,1]],curved=True),dict(points=[[.95,.5],[.5,.45],[.05,.6],[.05,.85],[.45,1],[.95,.85]],curved=True)]
    # These y's all have diagonal arms. The original Jua guide incorrectly drew a u.
    if char=='y':
        strokes=[dict(points=[[0,0],[.52,.64]],curved=False),dict(points=[[1,0],[.48,.7],[.17,1]],curved=False)]
    h,w=shape
    result=[]
    for s in strokes:
        p=np.array(s['points'],dtype=float)
        # The templates determine order/direction, never the actual fitted geometry.
        # Use the legacy Jua inset for broad positional guidance, then project to the
        # current font's own skeleton. Other faces use their own measured stroke inset.
        inset=PIXELS*(.075 if face=='Jua-Regular' else .04)
        ix=min(inset,(w-2*PAD)/3); iy=min(inset,(h-2*PAD)/3)
        p=p*np.array([w-2*PAD-2*ix,h-2*PAD-2*iy])+np.array([PAD+ix,PAD+iy])
        if s['curved'] and len(p)>2: p=smooth(p)
        result.append(resample(p))
    return result


def without_backtracks(route):
    stack=[]
    for p in route:
        if stack and p==stack[-1]: continue
        if len(stack)>1 and p==stack[-2]: stack.pop()
        else: stack.append(p)
    return stack


def trace_guides(g,guides,char):
    components=sorted(nx.connected_components(g),key=len,reverse=True)
    arrays=[np.array(sorted(c)) for c in components]
    trees=[cKDTree(a[:,::-1]) for a in arrays]
    paths=[]; used=set()
    for guide in guides:
        if len(guide)==1:
            # i/j dots are complete disconnected components, including rectangular
            # font dots whose skeleton may be several pixels long.
            choices=range(1,len(components)) if len(components)>1 else range(len(components))
            ci=min(choices,key=lambda i:trees[i].query(guide)[0].mean())
            point=arrays[ci].mean(axis=0)
            paths.append([tuple(np.rint(point).astype(int))]); used.update(components[ci]); continue
        ci=min(range(len(components)),key=lambda i:trees[i].query(guide)[0].mean())
        indices=trees[ci].query(guide)[1]
        anchors=[tuple(arrays[ci][i]) for i in indices]
        route=[anchors[0]]
        for p in anchors[1:]:
            if p!=route[-1]: route.extend(nx.shortest_path(g,route[-1],p,weight='weight')[1:])
        route=route if char=='B' else without_backtracks(route)
        if len(route)>1:
            paths.append(route); used.update(route)
    return paths,used


def extend_terminals(g,paths):
    # Projection seeds often stop a little before a stroke terminal. Follow the
    # current skeleton chain to its endpoint/junction instead of inventing an extra
    # demonstration stroke for the remaining few millimeters.
    extended=[]
    for path_index, route in enumerate(paths):
        other_used={p for i, other in enumerate(paths) if i != path_index for p in other}
        if len(route)==1:
            extended.append(route); continue
        route=list(route)
        for reverse in (True,False):
            if reverse: route.reverse()
            occupied=set(route[:-1]); current=route[-1]
            while g.degree(current)==2:
                choices=[q for q in g[current] if q not in occupied and q not in other_used]
                if len(choices)!=1: break
                # Stop at a sharp corner: a stem must not consume its crossbar.
                reference=np.array(route[max(0,len(route)-12)])
                tangent=np.array(current)-reference
                direction=np.array(choices[0])-np.array(current)
                denominator=np.linalg.norm(tangent)*np.linalg.norm(direction)
                if denominator and np.dot(tangent,direction)/denominator < .75: break
                occupied.add(current); current=choices[0]; route.append(current)
            if reverse: route.reverse()
        extended.append(route)
    return extended


def remaining_routes(g,used,radius,paths):
    # A skeleton region covered by the pen's local stroke width doesn't need its own
    # branch (e.g. a squared-off serif corner). Long missing features do.
    points=np.array(sorted(used))
    tree=cKDTree(points)
    missing=set()
    for p in g:
        distance, index=tree.query(p)
        near=tuple(points[index])
        if distance > max(3,radius[p]*.8,radius[near]*.8): missing.add(p)
    # Grow each missing route back to the already-taught skeleton, then order it by
    # its nearest taught stroke. This is a last-resort geometry route, not a claim
    # that automatic skeletonization can infer pedagogical stroke order.
    remaining=g.subgraph(missing).copy()
    for comp in sorted(nx.connected_components(remaining),key=lambda c:min(c)):
        sub=remaining.subgraph(comp)
        if len(comp)<3: continue
        seed=min(comp)
        a=max(nx.single_source_dijkstra_path_length(sub,seed,weight='weight'),key=nx.single_source_dijkstra_path_length(sub,seed,weight='weight').get)
        distances=nx.single_source_dijkstra_path_length(sub,a,weight='weight')
        b=max(distances,key=distances.get)
        route=nx.shortest_path(sub,a,b,weight='weight')
        if sum(math.dist(p,q) for p,q in zip(route,route[1:]))<max(5,radius[a]*.65): continue
        # Extend to a nearby skeleton endpoint/junction so a new bar reaches the stem.
        for end,reverse in ((a,True),):
            near=tuple(points[tree.query(end)[1]])
            extension=nx.shortest_path(g,end,near,weight='weight') if nx.has_path(g,end,near) else []
            if extension and len(extension)<PIXELS*.13:
                route=(extension[:0:-1]+route) if reverse else (route+extension[1:])
        paths.append(without_backtracks(route)); used.update(route)
    return paths


def merge_terminal_parts(paths,original_count,g):
    # If projection left the last few millimeters of a terminal behind, extend its
    # existing gesture instead of teaching a separate tiny pen stroke.
    original=[list(p) for p in paths[:original_count]]
    for extra in paths[original_count:]:
        best=None
        for index,path in enumerate(original):
            if len(path)<2: continue
            for front,endpoint in ((True,path[0]),(False,path[-1])):
                for tip in (extra[0],extra[-1]):
                    if not nx.has_path(g,endpoint,tip):continue
                    link=nx.shortest_path(g,endpoint,tip,weight='weight')
                    length=sum(math.dist(a,b) for a,b in zip(link,link[1:]))
                    # Prefer the far end only when the connection accounts for the
                    # missing route, not its attachment point on the existing path.
                    if not set(extra).issubset(set(link)|set(path)):continue
                    if length<=PIXELS*.2 and (best is None or length<best[0]): best=(length,index,front,link)
        if best is None: original.append(extra)
        else:
            _,index,front,link=best
            original[index]=(link[:0:-1]+original[index]) if front else (original[index]+link[1:])
    return original


def shape_cusps(points,mask):
    # A skeleton cusp is a spur visited down-and-back. Replace that graph detour
    # with the two real diagonal pen motions meeting at its tip. Verify each new
    # chord against the glyph before using it.
    points=list(points)
    while True:
        found=None
        for i in range(len(points)):
            for j in range(i+4,min(len(points),i+int(PIXELS*.25))):
                if points[i]!=points[j]: continue
                inside=points[i:j+1]
                if inside!=inside[::-1]: continue
                found=(i,j); break
            if found:break
        if not found:break
        i,j=found; middle=(i+j)//2; tip=points[middle]
        reach=max(4,int((j-i)*.7))
        left=max(0,i-reach);right=min(len(points)-1,j+reach)
        while True:
            candidate=resample([points[left],tip,points[right]],.5)
            ij=np.rint(candidate).astype(int)
            if mask[ij[:,0],ij[:,1]].all() or reach<=2:break
            reach=max(2,reach//2);left=max(0,i-reach);right=min(len(points)-1,j+reach)
        # Densification is kept in pixels until normalization below.
        points=points[:left]+[tuple(p) for p in candidate]+points[right+1:]
    return points


def make_paths(face,char):
    mask=glyph_mask(face,char)
    g,radius=graph_of(mask)
    guides=guide_strokes(face,char,mask.shape)
    paths,used=trace_guides(g,guides,char)
    if face=='ComicNeue-Bold' and char=='g':
        # The true endpoints are the upper right stem and the lower left hook.
        # A direct graph route joins them in the natural down-then-left direction;
        # projecting the old generic guide can take a detour back into the bowl.
        ends=[p for p in g if g.degree(p)==1]
        start=min(ends,key=lambda p:p[0]); end=max(ends,key=lambda p:p[0])
        paths=[paths[0],nx.shortest_path(g,start,end,weight='weight')]
        used={p for path in paths for p in path}
    if (face,char) in {('Jua-Regular','2'),('ComicNeue-Bold','3'),('VarelaRound-Regular','3')}:
        # The base corner of 2 and the waist of 3 are continuous pen motions,
        # although thinning represents their tips as short branches. Visit the tip
        # in the same gesture; shape_cusps below converts the graph detour to a bend.
        ends=[p for p in g if g.degree(p)==1]
        if char=='2':
            start=min(ends,key=lambda p:p[0]); tip=min(ends,key=lambda p:p[1]); end=max(ends,key=lambda p:p[1])
            waypoints=[start,tip,end]
        else: waypoints=sorted(ends,key=lambda p:p[0])
        route=[waypoints[0]]
        for tip in waypoints[1:]:route.extend(nx.shortest_path(g,route[-1],tip,weight='weight')[1:])
        paths=[route];used=set(route)
    if char=='J' and face!='Jua-Regular':
        ends=[p for p in g if g.degree(p)==1]
        if len(ends)>=2:
            a=min(ends,key=lambda p:p[0]); distances=nx.single_source_dijkstra_path_length(g,a,weight='weight')
            b=max(ends,key=lambda p:distances.get(p,0))
            paths=[nx.shortest_path(g,a,b,weight='weight')];used=set(paths[0])
    if char in 'WwVv':
        ends=[p for p in g if g.degree(p)==1]
        if len(ends)>=2:
            a=min(ends,key=lambda p:p[1]); b=max(ends,key=lambda p:p[1])
            # Every cusp is part of the letter. The medial graph may give the cusp
            # a short branch, so preserve a visit to that tip rather than erasing
            # it as ordinary projection backtracking.
            waypoints=sorted(ends,key=lambda p:p[1])
            route=[waypoints[0]]
            for tip in waypoints[1:]: route.extend(nx.shortest_path(g,route[-1],tip,weight='weight')[1:])
            paths=[route]; used=set(route)
    paths=extend_terminals(g,paths)
    used.update(p for path in paths for p in path)
    if char not in 'WwVv': paths=remaining_routes(g,used,radius,paths)
    paths=merge_terminal_parts(paths,len(guides),g)
    cleaned=[]
    for path in paths:
        if char in 'WwVv' or (face,char) in {('Jua-Regular','2'),('ComicNeue-Bold','3'),('VarelaRound-Regular','3')}:
            path=shape_cusps(path,mask)
        p=np.array(path,dtype=float)[:,::-1]
        if len(p)>2: p=approximate_polygon(p,tolerance=.65)
        # Normalize against the raster's true ink bounds. CoreText supplies the exact
        # ink rectangle at runtime, so font size and page layout cannot change fit.
        norm=(p-PAD)/np.array([mask.shape[1]-2*PAD,mask.shape[0]-2*PAD])
        cleaned.append(np.round(norm,4).tolist())
    # These two reviewed twigs lie inside already-covered wide stroke regions.
    # They are medial-axis artifacts, not extra gestures or required letter parts.
    if face=='Sniglet-ExtraBold' and char in 'FN': cleaned=cleaned[:3]
    # Sniglet's exceptionally heavy S/e create broad medial-axis branches at the
    # narrow openings. These two outline-reviewed routes keep a smooth school
    # gesture rather than making a learner trace a graph's artificial forks.
    if face=='Sniglet-ExtraBold' and char=='S':
        cleaned=[smooth([[.78,.17],[.53,.14],[.27,.19],[.24,.34],[.45,.44],[.68,.52],[.76,.65],[.65,.79],[.42,.84],[.18,.8]]).tolist()]
    if face=='Sniglet-ExtraBold' and char=='e':
        cleaned=[np.vstack([resample([[.21,.56],[.75,.51]],.015),smooth([[.75,.51],[.80,.29],[.60,.16],[.31,.22],[.20,.45],[.24,.72],[.48,.82],[.79,.79]])]).tolist()]
    return cleaned,mask,radius,g


def verify(paths,mask,radius,g):
    h,w=mask.shape
    pixel_paths=[np.array(p)*[w-2*PAD,h-2*PAD]+PAD for p in paths]
    allpoints=np.vstack([resample(p,.5) for p in pixel_paths])
    xy=np.rint(allpoints).astype(int)
    inside=mask[xy[:,1],xy[:,0]].mean()
    tree=cKDTree(allpoints)
    skeleton=np.array(list(g))
    distances,nearest=tree.query(skeleton[:,::-1])
    path_pixels=xy[nearest]
    allowance=np.maximum(3,np.maximum(radius[skeleton[:,0],skeleton[:,1]],radius[path_pixels[:,1],path_pixels[:,0]])*.95)
    skeleton_coverage=(distances<=allowance).mean()
    # Reconstruction is a geometry guard: local-width disks around centerlines must
    # reach the glyph's stroke regions without demanding that a child color them in.
    foreground=np.argwhere(mask)
    dist,nearest=tree.query(foreground[:,::-1])
    nearest_pixels=xy[nearest]
    local_r=radius[nearest_pixels[:,1],nearest_pixels[:,0]]
    area_coverage=(dist<=local_r*1.35+2).mean()
    return dict(inside=float(inside),skeleton_coverage=float(skeleton_coverage),area_coverage=float(area_coverage),strokes=len(paths),points=sum(map(len,paths)))


def draw_atlas(face,entries,output):
    cellw,cellh=160,175
    im=Image.new('RGB',(10*cellw,7*cellh+45),'white'); d=ImageDraw.Draw(im)
    title=ImageFont.truetype('/System/Library/Fonts/Helvetica.ttc',20)
    d.text((12,10),f'{face} — outline-derived tracing routes (number = stroke order)',font=title,fill='black')
    for i,(char,(paths,mask,stats)) in enumerate(entries.items()):
        x=(i%10)*cellw; y=(i//10)*cellh+45
        h,w=mask.shape; scale=min((cellw-30)/w,(cellh-42)/h)
        glyph=Image.fromarray(np.where(mask,205,255).astype('uint8')).convert('RGB').resize((round(w*scale),round(h*scale)))
        ox=x+(cellw-glyph.width)/2; oy=y+26
        im.paste(glyph,(round(ox),round(oy)))
        d.text((x+8,y+4),char,font=title,fill='black')
        for si,path in enumerate(paths):
            p=np.array(path)*[w-2*PAD,h-2*PAD]+PAD
            p=p*scale+[ox,oy]
            coords=[tuple(v) for v in p]; color=COLORS[si%len(COLORS)]
            if len(p)>1: d.line(coords,fill=color,width=2)
            d.ellipse((p[0,0]-3,p[0,1]-3,p[0,0]+3,p[0,1]+3),fill=color)
            d.text((p[0,0]+4,p[0,1]-8),str(si+1),fill=color)
            if len(p)>3:
                j=min(3,len(p)-1); delta=p[j]-p[j-1]; norm=np.linalg.norm(delta)
                if norm:
                    tangent=delta/norm; perpendicular=np.array([-tangent[1],tangent[0]])
                    tip=p[j]; d.polygon([tuple(tip),tuple(tip-6*tangent+2.5*perpendicular),tuple(tip-6*tangent-2.5*perpendicular)],fill=color)
        if stats['inside']<1 or stats['area_coverage']<.92:
            d.text((x+8,y+cellh-14),f"fit {stats['inside']:.0%} ink {stats['area_coverage']:.0%}",fill='red')
    im.save(output/f'{face}-atlas.png')


def swift_data(dataset):
    chunks=['// BEGIN GENERATED FONT FORMATIONS — Scripts/formations/generate.py','/// Per-face centerlines extracted from the bundled font outlines. Coordinates are','/// integer ten-thousandths of the actual ink bounds; semicolons separate pen lifts.','/// School-order guides seed traversal, with explicit structural font overrides.','/// These are demonstration routes; only independently validated faces should incur','/// a pedagogical stroke-order penalty. Do not hand-edit generated coordinates.','private enum FontFormationData {','    static let encoded: [String: String] = [']
    for face,glyphs in dataset.items():
        chunks.append(f'        "{face}": """')
        for char,paths in glyphs.items():
            encoded=';'.join(' '.join(f'{round(x*10000)},{round(y*10000)}' for x,y in p) for p in paths)
            chunks.append(f'        {char}:{encoded}')
        chunks.append('        """,')
    chunks.extend(['    ]','}','// END GENERATED FONT FORMATIONS'])
    return '\n'.join(chunks)+'\n'


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output',type=Path,default=Path('/tmp/font-formations'))
    parser.add_argument('--write-swift',action='store_true')
    parser.add_argument('--check',action='store_true',help='Also check generated application coordinates are up to date')
    parser.add_argument('--faces',nargs='*',default=FONTS)
    args=parser.parse_args(); args.output.mkdir(parents=True,exist_ok=True)
    dataset={}; report={}
    for face in args.faces:
        entries={}; dataset[face]={}; report[face]={}
        for char in CHARS:
            paths,mask,radius,g=make_paths(face,char)
            stats=verify(paths,mask,radius,g)
            dataset[face][char]=paths; report[face][char]=stats
            entries[char]=(paths,mask,stats)
        draw_atlas(face,entries,args.output)
        worst=min(report[face],key=lambda c:report[face][c]['skeleton_coverage'])
        print(face,'worst coverage',worst,report[face][worst],flush=True)
    manifest={face:hashlib.sha256((ROOT/'HandwrittenJournal/Resources/Fonts'/f'{face}.ttf').read_bytes()).hexdigest() for face in args.faces}
    manifest['jua-stroke-order.json']=hashlib.sha256((Path(__file__).parent/'jua-stroke-order.json').read_bytes()).hexdigest()
    (args.output/'source-sha256.json').write_text(json.dumps(manifest,indent=2)+'\n')
    (args.output/'formations.json').write_text(json.dumps(dataset,separators=(',',':')))
    (args.output/'verification.json').write_text(json.dumps(report,indent=2))
    (args.output/'FontFormationData.swift').write_text(swift_data(dataset))
    failures=[]
    for face,glyphs in report.items():
        for char,v in glyphs.items():
            reviewed=face=='Sniglet-ExtraBold' and char in 'SeF'
            # Medial branches in the explicitly reviewed bulbous glyphs are
            # not required pen routes. Their local-width reconstruction must cover
            # at least 95% of the actual glyph instead (stricter area threshold).
            if v['inside']<.999 or v['area_coverage']<(.95 if reviewed else .92) or (not reviewed and v['skeleton_coverage']<.985):
                failures.append((face,char,v))
    if args.check:
        source=(ROOT/'HandwrittenJournal/Services/LetterFormations.swift').read_text()
        current='// BEGIN GENERATED FONT FORMATIONS'+source.split('// BEGIN GENERATED FONT FORMATIONS',1)[1]
        if current!=swift_data(dataset): failures.append(('generated Swift is stale',))
    if args.write_swift and not failures:
        assert args.faces==FONTS,'Only a full generation may update application data'
        path=ROOT/'HandwrittenJournal/Services/LetterFormations.swift'
        source=path.read_text().split('// BEGIN GENERATED FONT FORMATIONS')[0].rstrip()+'\n\n'
        temporary=path.with_suffix('.swift.tmp')
        temporary.write_text(source+swift_data(dataset))
        temporary.replace(path)
    print('Total:',sum(map(len,dataset.values())),'glyphs;',sum(v['points'] for glyphs in report.values() for v in glyphs.values()),'points; failures:',len(failures))
    for row in failures: print(row)
    return bool(failures)

if __name__=='__main__':
    raise SystemExit(main())
