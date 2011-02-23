(* module transforming anonymous functions into partial applications *)

open Utils
open Ist

module FreeVars = struct

  let rec pat fv ptl = 
    List.fold_left pat_tuple fv ptl 

  and pat_tuple fv pel = List.fold_left pat_el fv pel 
  and pat_el fv (ty, pe) = pat_ fv ty pe 
  and pat_ fv ty = function
    | Pany -> fv
    | Pid x -> IMap.remove x fv 
    | Pvalue _ -> fv
    | Pvariant (_, p) -> pat fv p
    | Precord pfl -> List.fold_left pat_field fv pfl
    | Pas (x, p) -> 
	let fv = pat fv p in
	IMap.remove x fv

  and pat_field fv = function
    | PFany -> fv
    | PFid x -> IMap.remove x fv 
    | PField (_, p) -> pat fv p 

  and tuple fv el = List.fold_left expr fv el
  and expr fv (ty, e) = expr_ fv ty e
  and expr_ fv ty = function
    | Eid x as v -> IMap.add x (ty, v) fv
    | Evalue _ -> fv
    | Evariant (id, t) ->
	let fv = tuple fv t in
	fv
    | Ebinop (_, e1, e2) ->
	let fv = expr fv e1 in
	let fv = expr fv e2 in
	fv
    | Euop (_, e1) -> 
	let fv = expr fv e1 in
	fv
    | Erecord fdl ->
	fields fv fdl
    | Ewith (e, fdl) ->
	let fv = expr fv e in
	let fv = fields fv fdl in
	fv
    | Efield (e, id)  ->
	let fv = expr fv e in
	fv
    | Ematch (t, al) ->
	let fv = tuple fv t in
	let fv = actions fv al in
	fv
    | Elet (p, t1, t2) ->
	let fv = tuple fv t1 in
	let fv = tuple fv t2 in
	let fv = pat fv p in
	fv
    | Eif (e, t1, t2) ->
	let fv = expr fv e in
	let fv = tuple fv t1 in
	let fv = tuple fv t2 in
	fv
    | Eapply (_, _, _, t) ->
	let fv = tuple fv t in
	fv
    | Eseq (e, t) ->
	let fv = expr fv e in
	let fv = tuple fv t in
	fv
    | Efree _ -> fv
    | Eset (e1, e2, e3) ->
	let fv = expr fv e1 in
	let fv = expr fv e2 in
	let fv = expr fv e3 in
	fv
    | Eget (e1, e2) ->
	let fv = expr fv e1 in
	let fv = expr fv e2 in
	fv
    | Eswap (e1, e2, e3) ->
	let fv = expr fv e1 in
	let fv = expr fv e2 in
	let fv = expr fv e3 in
	fv
    | Epartial (e, t) ->
	let fv = expr fv e in
	let fv = tuple fv t in
	fv
    | Efun (k, pel, t) ->
	let t = tuple fv t in
	pat_tuple t pel

  and fields x y = List.fold_left field x y
  and field fv (_, t) = tuple fv t
  and actions x y = List.fold_left action x y
  and action fv (p, t) =
    let fv = tuple fv t in
    pat fv p
	  
end

let rec program mdl = 
  List.rev_map module_ mdl

and module_ md = 
  let funs = md.md_decls, [] in
  let decls, defs = List.fold_left def funs md.md_defs in
  { md with md_decls = decls ; md_defs = defs }

and def (decls, defs) (k, x, p, e) = 
  let (decls, defs), e = tuple (decls, defs) e in
  let defs = (k, x, p, e) :: defs in
  decls, defs

and tuple funs el = lfold expr funs el

and expr funs (ty, e) = 
  let funs, e = expr_ funs ty e in
  funs, (ty, e)

and expr_ funs ty = function
  | Eid _
  | Evalue _ as x -> funs, x
  | Evariant (x, t) ->
      let funs, t = tuple funs t in
      funs, Evariant (x, t)
  | Ebinop (op, e1, e2) ->
      let funs, e1 = expr funs e1 in
      let funs, e2 = expr funs e2 in
      funs, Ebinop (op, e1, e2)
  | Euop (op, e1) -> 
      let funs, e1 = expr funs e1 in
      funs, Euop (op, e1)
  | Erecord fdl ->
      let funs, fdl = lfold field funs fdl in
      funs, Erecord fdl
  | Ewith (e, fdl) ->
      let funs, e = expr funs e in
      let funs, fdl = lfold field funs fdl in
      funs, Ewith (e, fdl)
  | Efield (e, id)  ->
      let funs, e = expr funs e in
      funs, Efield (e, id) 
  | Ematch (t, al) ->
      let funs, t = tuple funs t in
      let funs, al = lfold action funs al in
      funs, Ematch (t, al)
  | Elet (p, t1, t2) ->
      let funs, t1 = tuple funs t1 in
      let funs, t2 = tuple funs t2 in
      funs, Elet (p, t1, t2)
  | Eif (e, t1, t2) ->
      let funs, e = expr funs e in
      let funs, t1 = tuple funs t1 in
      let funs, t2 = tuple funs t2 in
      funs, Eif (e, t1, t2)
  | Eapply (k, ty, x, t) ->
      let funs, t = tuple funs t in
      funs, Eapply (k, ty, x, t)
  | Eseq (e, t) ->
      let funs, e = expr funs e in
      let funs, t = tuple funs t in
      funs, Eseq (e, t)
  | Efree _ as x -> funs, x
  | Eset (e1, e2, e3) ->
      let funs, e1 = expr funs e1 in
      let funs, e2 = expr funs e2 in
      let funs, e3 = expr funs e3 in
      funs, Eset (e1, e2, e3)
  | Eget (e1, e2) ->
      let funs, e1 = expr funs e1 in
      let funs, e2 = expr funs e2 in
      funs, Eget (e1, e2)
  | Eswap (e1, e2, e3) ->
      let funs, e1 = expr funs e1 in
      let funs, e2 = expr funs e2 in
      let funs, e3 = expr funs e3 in
      funs, Eswap (e1, e2, e3)
  | Epartial (e, t) ->
      let funs, e = expr funs e in
      let funs, t = tuple funs t in
      funs, Epartial (e, t)
  | Efun (k, pel, t) as e ->
      let fv = FreeVars.expr_ IMap.empty ty e in
      let fvl = IMap.fold (fun _ v y -> v :: y) fv [] in
      match fvl with
      | [] -> make_fun funs ty k pel t
      | args -> partial funs ty k pel t args

and field funs (p, t) = 
  let funs, t = tuple funs t in
  funs, (p, t)

and action funs (p, t) = 
  let funs, t = tuple funs t in
  funs, (p, t)

and make_fun (decls, defs) fty k pel t = 
  let fty = List.hd fty in
  let fid = Ident.tmp() in
  let decl = Dval (Ast.Private, fid, fty, Ast.Ext_none) in
  let def = k, fid, [pel], t in
  let decls = decl :: decls in
  let defs = def :: defs in
  (decls, defs), Eid fid

and partial funs fty k pel t args =
  let funs, f = make_fun funs fty k pel t in
  funs, Epartial ((fty, f), args)