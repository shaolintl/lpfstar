(*
  EVERYTHING IS AN INDUCTIVE TYPE
*)

include "basics/pts.ma".

(* As we mentioned several times, very few notions are really primitive in 
Matita: one of them is the notion of universal quantification (or dependent 
product type) and the other one is the notion of inductive type. Even the arrow 
type A → B is not really primitive: it can be seen as a particular case of the 
dependent product ∀x:A.B in the degenerate case when B does not depends on x. 
All the other familiar logical connectives - conjunction, disjunction, negation, 
existential quantification, even equality - can be defined as particular 
inductive types.
  We shall look at these definitions in this section, since it can be useful to 
acquire confidence with inductive types, and to get a better theoretical grasp 
over them.
*)

(******************************* Conjunction **********************************)

(* In natural deduction, logical rules for connectives are divided in two 
groups: there are introduction rules, allowing us to introduce a logical 
connective in the conclusion, and there are elimination rules, describing how to 
de-construct information about a compound proposition into information about its 
constituents (that,is, how to use an hypothesis having a given connective as its 
principal operator).

Consider conjunction. In order to understand the introduction rule for 
conjunction, you should answer the question: how can we prove A∧B? The answer is 
simple: we must prove both A and B. Hence the introduction rule for conjunction 
is A → B → A∧B.

The general idea for defining a logical connective as an inductive type is 
simply to define it as the smallest proposition generated by its introduction 
rule(s). 

For instance, in the case of conjunction, we have the following definition: *)

inductive And (A,B:Prop) : Prop ≝
    conj : A → B → And A B.

(* The corresponding elimination rule is induced by minimality: if we have a 
proof of A∧B it may only derive from the conjunction of a proof of A and a proof 
of B. A possible way to formally express the elimination rule is the following: 

    And_elim: ∀A,B,P:Prop. (A → B → P) → A∧B → P
   
that is, for all A and B, and for any proposition P if we need to prove P under
the assumption A∧B, we can reduce it to prove P under the pair of assumptions A 
and B.

It is interesting to observe that the elimination rule can be easily derived 
from the introduction rule in a completely syntactical way.
Basically, the general structure of the (non recursive, non dependent) 
elimination rule for an inductive type T is the following

    ∀A1,… An.∀P:Prop. C1 → … →  Cn → T → P
    
where A1, … An are the parameters of the inductive type, and every Ci is derived 
from the type Ti of a constructor ci of T by just replacing T with P in it. For 
instance, in the case of the conjunction we only have one constructor of type 
A → B → A∧B  and replacing A∧B with P we get C = A \to B \to P.

Every time we declare a new inductive proposition or type T, Matita 
automatically generates an axiom called T\_ind that embodies the elimination 
principle for this type. The actual shape of the elimination axiom is sensibly 
more complex of the one described above, since it also takes into account the 
possibility that the predicate P depends over the term of the given inductive 
type (and possible arguments of the inductive type). 
We shall discuss the general case in Section ??.

Actually, the elimination tactic elim for an element of type T is a 
straightforward wrapper that applies the suitable elimination axiom.  
Let us see this in action on a simple lemma. Suppose we want to prove the 
following trivial result:
*)
lemma And_left: ∀A,B:Prop. And A B →A.
(* After introducing A and B we could decompose with * the hypothesis A∧B to 
get the two premises A and B and use the former to close the goal, as expressed
by the following commands
   #A #B * // qed.
However, a viable alternative is to explicitly apply the elimination principle:
*)
#A #B @And_ind // qed. 


(********************************* Disjunction ********************************)

(* Let us apply the previous methodology to other connectives, starting with 
disjunction. The first point is to derive the introduction rule(s). When can we 
conclude A∨B? Clearly, we must either have a proof of A, or a proof of B. So, we 
have two introduction rules, in this case: 
      A → A∨B    and    
      B → A∨B
that leads us to the following inductive definition of disjunction: *)

inductive Or (A,B:Prop) : Prop ≝
     or_introl : A → Or A B
   | or_intror : B → Or A B.
   
(* The elimination principle, automatically generated by the system is

   or_ind: ∀A,B,P:Prop. (A → P) → (B → P) → A∨B → P
   
that is a traditional formulation of the elimination rule for the logical 
disjunction in natural deduction: if P follows from both A and B, then it also 
follows from their disjunction. *)

(************************************ False ***********************************)

(* More surprisingly, we can apply the same methodology to define the constant 
False. The point is that, obviously, there is no (canonical) way to conclude 
False: so we have no introduction rule, and we must define an inductive type 
without constructors, that is accepted by the system. *)

inductive False: Prop ≝ .

(* The elimination principle is in this case 

  False_ind: ∀P:Prop.False → P
  
that is the well known principle of explosion: ``ex falso quodlibet''. *)

(************************************ True ************************************)

(* What about True? You may always conclude True, hence the corresponding
inductive definition just has one trivial constructor, traditionally named I: *)

inductive True: Prop ≝ I : True.

(* As expected, the elimination rule is not informative in this case: the only 
way to conclude P from True is to prove P:

   True_ind: ∀P:Prop.P → True → P 
*)

(******************************** Existential *********************************)

(* Finally, let us consider the case of existential quantification. In order to 
conclude ∃x:A.Q x we need to prove Q a for some term a:A. Hence, the 
introduction rule for the existential looks like the following:

    ∀a:A. Q a → ∃x.Q x
    
from which we get the following inductive definition, parametric in A and Q: *)

inductive ex (A:Type[0]) (Q:A → Prop) : Prop ≝
    ex_intro: ∀x:A. Q x →  ex A Q.
    
(* The elimination principle automatically generated by Matita is
  
   ex_ind: ∀A.∀Q:A→Prop.∀P:Prop. (∀x:A. Q x → P) → ∃x:A.Q → P
   
That is, if we know that P is a consequence of Q x for any x:A, then it is 
enough to know ∃x:A.Q x to conclude P. It is also worth to spell out the 
backward reading of the previous principle.
Suppose we need to prove P under the assumption ∃x:A.Q. Then, eliminating the 
latter amounts to assume the existence of x:A such that Q\; x and proceed 
proving P under these new assumptions. *)

(****************************** A bit of notation *****************************)

(* Since we make a frequent use of logical connectives and quantifiers, it would 
be nice to have the possibility to use a more familiar-looking notation for 
them. As a matter of fact, Matita offers you the possibility to associate your 
own notation to any notion you define.

To exploit the natural overloading of notation typical of scientific literature, 
its management is splitted in two steps, in Matita: one from presentation level 
to content level, where we associate a notation to a fragment of abstract 
syntax, and one from content level to term level, where we provide (possibly 
multiple) interpretations for the abstract syntax. 

The mapping between the presentation level (i.e. what is typed on the keyboard 
and what is displayed in the sequent window) and the content level is defined 
with the "notation" command. When followed by >, it defines an input (only) 
notation (that is, used in parsing but not in pretty printing). *)

notation "hvbox(a break \land b)"
  left associative with precedence 35 for @{ 'and $a $b }.

(* This declaration associates the infix notation "a \lanb b" - rendered a ∧ b 
by the UTF-8 graphical facilities - with an abstract syntax tree composed by the 
new symbol 'and applied to the result of the parsing of input argument a and b.
 
The presentation pattern is always enclosed in double quotes. The special 
keyword "break" indicates the breaking point and the box schema hvbox indicates 
a horizontal or vertical layout, according to the available space for the 
rendering (they can be safely ignored for the scope of this tutorial). 

The content pattern begins right after the for keyword and extends to the end of 
the declaration. Parts of the pattern surrounded by @{… } denote verbatim 
content fragments, those surrounded by ${… }$ denote meta-operators and 
meta-variables (for example $a) referring to the meta-variables occurring in
the presentation pattern.

The declaration also instructs the system that the notation is supposed to be 
left associative and provides information about the syntactical precedence of 
the operator, that governs the way an expression with different operators is 
interpreted by the system.
For instance, suppose we declare the logical disjunction at a lower precedence:
*)

notation "hvbox(a break \lor b)" 
  left associative with precedence 30 for @{ 'or $a $b }.

(* Then, an expression like A ∧ B ∨ C will be understood as (A ∧ B) ∨ C and not 
A ∧ (B ∨ C).
An annoying aspect of notation is that it will eventually interfere with the 
system parser, so introducing operators with the suitable precedence is an 
important and delicate issue. The best thing to do is to consult the file 
``basics/core\_notation.ma'' and, unless you cannot reuse an already existing 
notation overloading it (that is the recommended solution), try to figure out by 
analogy the most suited precedence for your operator. 

We cannot use the notation yet. Suppose we type: 

    lemma And_comm: ∀A,B. A∧B → B∧A.

Matita will complain saying that there is no interpretation for the symbol
'and. In order to associate an interpretation with content 
elements, we use the following commands: *)

interpretation "logical and" 'and x y = (And x y).
interpretation "logical or" 'or x y = (Or x y).

(* With these commands we are saying that a possible interpretation of the 
symbol 'and+ is the inductive type And, and a possible interpretation of the 
symbol 'or is the inductive type Or. 
Now, the previous lemma is accepted: *)

lemma And_comm: ∀A,B. A∧B → B∧A.
#A #B * /2/ qed.

(* We can give as many interpretations for a same symbol as we wish: Matita will
automatically try to guess the correct one according to the context inside which
the expression occurs.
To make an example, let us define booleans and two boolean functions andb and 
orb. *)

inductive bool : Type[0] ≝ tt : bool | ff : bool.

definition andb ≝ λb1,b2. 
  match b1 with [tt ⇒ b2 | ff ⇒ ff ].
  
definition orb ≝ λb1,b2. 
  match b1 with [tt ⇒ tt | ff ⇒ b2 ].

(* Then, we could then provide alternative interpretations of 'and and 'or+ over 
them: *)

interpretation "boolean and" 'and x y = (andb x y).
interpretation "boolena or" 'or x y = (orb x y).

(* In the following lemma, the disjunction would be intrerpreted as 
propositional disjunnction, since A and B must be propositions *)

lemma Or_comm: ∀A,B. A∨B → B∨A.
#A #B * /2/ qed.

(* On the other side, in the following lemma the disjunction is interpreted as
boolean disjunction, since a and b are boolean expressions *)

lemma andb_comm: ∀a,b.∀P:bool→Prop. P (a∨b) → P (b∨a).
* * // qed.

(* Let us conclude this section with a discussion of the notation for the 
existential quantifier. *)

notation "hvbox(\exists ident i : ty break . p)"
  right associative with precedence 20 for 
  @{'exists (\lambda ${ident i} : $ty. $p) }.

(* The main novelty is the special keyword "ident" that instructs the system
that the variable i is expected to be an identifier. Matita abstract syntax
trees include lambda terms as primitive data types, and the previous declaration 
simply maps the notation ∃x.P into a content term of the form ('exists (λx.p))  
where p is the content term obtained from P.

The corresponding interpretation is then straightforward: *)

interpretation "exists" 'exists x = (ex ? x).

(* The notational language of Matita has an additional list operator for dealing 
with variable-size terms having a regular structure. Such operator has a 
corresponding fold operator, to build up trees at the content level. 

For example, in the case of quantifiers, it is customary to group multiple 
variable declarations under a same quantifier, writing e.g. ∃x,y,z.P instead of 
∃x.∃y.∃z.P.

This can be achieved by the following notation: *)

notation > "\exists list1 ident x sep , opt (: T). term 19 Px"
  with precedence 20
  for ${ default
          @{ ${ fold right @{$Px} rec acc @{'exists (λ${ident x}:$T.$acc)} } }
          @{ ${ fold right @{$Px} rec acc @{'exists (λ${ident x}.$acc)} } }
       }.

(* The presentational pattern matches terms starting with the existential 
symbol, followed by a list of identifiers separated by commas, optionally 
terminated by a type declaration, followed by a fullstop and finally by the body 
term. We use list1 instead of list0 since we expect to have at least one 
identifier: conversely, you should use list0 when the list can possibly be 
empty.

The "default" meta operator at content level matches the presentational opt and 
has two branches, which are chosen depending on the matching of the optional 
subexpression. Let us consider the first, case, where we have
an explicit type. The content term is build by folding the function 

              rec acc @{'exists (λ${ident x}:$T.$acc)}

(where "rec" is the binder, "acc" is the bound variable and the rest is the 
body) over the initial content expression @{$Px}. *)

lemma distr_and_or_l : ∀A,B,C:Prop. A ∧(B ∨ C) → (A ∧ B) ∨ (A ∧ C).
#A #B #C * #H *
 [#H1 %1 % [@H |@H1] |#H1 %2 % //]
qed.

lemma distr_and_or_r : ∀A,B,C:Prop. (A ∧ B) ∨ (A ∧ C) → A ∧ (B ∨ C).
#A #B #C * * #H1 #H2 
  [% [// | %1 //] | % [// | %2 //]
qed.


lemma distr_or_and_l : ∀A,B,C:Prop. A ∨(B ∧ C) → (A ∨ B) ∧ (A ∨ C).
#A #B #C *
 [#H % [%1 // |%1 //] | * #H1 #H2 % [%2 // | %2 //] ] 
qed.

lemma distr_or_and_r : ∀A,B,C:Prop. (A ∨ B) ∧ (A ∨ C) → A ∨ (B ∧ C).
#A #B #C 
* * #H * /3/ 
qed.

definition neg ≝ λA:Prop. A → False.

lemma neg_neg : ∀A. A → neg (neg A).
#A #H normalize #H1 @(H1 H)
qed.

(***************************** Leibniz Equality *******************************)

(* Even equality is a derived notion in Matita, and a particular case of an
inductive type. The idea is to define it as the smallest relation containing 
reflexivity (that is, as the smallest reflexive relation over a given type). *)

inductive eq (A:Type[0]) (x:A) : A → Prop ≝
    refl: eq A x x. 

(* We can associate the standard infix notation for equality via the following
declarations: *)

notation "hvbox(a break = b)" 
  non associative with precedence 45 for @{ 'eq ? $a $b }.

interpretation "leibnitz's equality" 'eq t x y = (eq t x y).

(* The induction principle eq_ind automatically generated by the system 
(up to dependencies) has the following shape:

    ∀A:Type[0].∀x:A. ∀P:A→Prop. P x → ∀y:A. x = y → P y
  
This principle is usually known as ``Leibniz equality'': two objects x and y are 
equal if they cannot be told apart, that is for any property P, P x implies P y.

As a simple exercise, let us also proof the following variant: *)
 
lemma eq_ind_r: ∀A:Type[0].∀x:A. ∀P:A→Prop. P x → ∀y:A. y = x → P y.
#A #x #P #Hx #y #eqyx <eqyx in Hx; // qed.

(* The order of the arguments in eq_ind may look a bit aleatoric but, as we shall 
see, it is motivated by the underlying structure of the inductive type.
Before discussing the way eq_ind is generated, it is time to make an important 
discussion about the parameters of inductive types.

If you look back at the definition of equality, you see that the first argument 
x has been explicitly declared, together with A, as a formal parameter of the 
inductive type, while the second argument has been left implicit in the 
resulting type A → Prop. One could wonder if this really matters, and in 
particular if we could use the following alternative definitions: 

    inductive eq1 (A:Type[0]) (x,y:A) : Prop ≝
      refl1: eq1 A x x. 
    
    inductive eq2 (A:Type[0]): A → A → Prop ≝
      refl2: ∀x.eq2 A x x. 
      
The first one is just wrong. If you try to type it, you get the following error 
message: ``CicUnification  failure: Can't unify x with y''.
The point is that the role of parameters is really to define a family of types 
uniformly indexed over them. This means that we expect all occurrences of the 
inductive type in the type of constructors to be precisely instantiated with the 
input parameters, in the order they are declared. So, if A,x and y are 
parameters for eq1, then all occurrences of this type in the type of 
constructors must have be of the kind eq1 A x y (while we have eq1 A x x, that 
explains the typing error). 

If you cannot express an argument as a parameter, the only alternative is to
implicitly declare it in the type of the inductive type. 
Henceforth, when we shall talk about ``arguments'' of inductive types, we shall 
implicitly refer to arguments which are not parameters (sometimes, people call 
them ``right'' and ``left'' parameters, according to their position w.r.t the 
double points in the type declaration. In general, it is always possible to 
declare everything as an argument, but it is a very good practice to shift as 
many argument as possible in parameter position. In particular, the definition
of eq2 is correct, but the corresponding induction principle eq2_ind is not as 
readable as eq_ind. *)

inductive eq2 (A:Type[0]): A → A → Prop ≝
      refl2: ∀x.eq2 A x x. 

(* The elimination rule for a (non recusive) inductive type T having a list
of parameters A1,…,An and a list of arguments B1,…,Bm, has the following shape 
(still, up to dependencies): 

  ∀a1:A1,… ∀an:An,∀P:B1 → … → Bm → Prop. 
     C1 → … →  Ck → ∀x1:B1…∀xm:Bm.T a1 … an b1 … bm → P x1 … xm 

where Ci is obtained from the type Ti of the constructor ci replacing in it each 
occurrence of (T a1 … an t1 … tm) with (P t1 … tm). 

For instance, eq2 only has A as parameter, and two arguments.
The corresponding elimination principle eq2_ind is as follows:

  ∀A:Type[0].∀P:A → A → Prop. ∀z.P z z →  ∀x,y:A. eq2 A x y → P x y 
  
As we prove below, eq2_ind and eq_ind are logically equivalent (that is, they 
mutually imply each other), but eq2_ind is slighty more complex and innatural. 
*)

lemma eq_to_eq2: ∀A,a,b. a = b → eq2 A a b.
#A #a #b #Heq <Heq // qed.

lemma eq2_to_eq: ∀A,a,b. eq2 A a b → a = b.
#A #a #b #Heq2 elim Heq2 // qed.

(******************* Equality, convertibility, inequality *********************)

(* Leibniz equality is a pretty syntactical (intensional) notion: two objects 
are equal when they are the ``same'' term. There is however, an important point 
to understand here: the notion of equality on terms is convertibility: two terms 
are equal if they are identical once they have been transformed in normal form. 
For this reason, not only 2=2 but also 1+1=2 since the normal form of 1+1 is 2.

Having understood the notion of equality, one could easily wonder how can we 
prove that two objects are differents. For instance, in Peano arithmetics, the 
fact that for any x, 0 ≠ S x is an independent axiom. With our inductive 
definition on natural numbers, can we prove it, or are we supposed to assume 
such a property axiomatically? *)

inductive nat : Type[0] ≝ 
    O : nat 
  | S : nat →nat.

(* In fact, in a logical system like the Calculus of Construction it is possible 
to prove it. We shall discuss the proof here, since it is both elegant and 
instructive.  

The crucial point is to define, by case analysis on the structure of the 
inductive term, a characteristic property for the different cases. 

For instance, in the case of natural numbers, we could define a
property not_zero as follow: *)

definition not_zero: nat → Prop ≝
 λn: nat. match n with [ O ⇒ False | (S p) ⇒ True ].

(* The possibility of defining predicates by structural recursion on terms is 
one of the major characteristic of the Calculus of Inductive Constructions, 
known as strong elimination. 

Suppose now we want to prove the following property: *)

theorem not_eq_O_S : ∀n:nat. O = S n → False.
#n #H

(* After introducing n and the hypothesis H:O = S n we are left with the goal 
False. Now, observe that (not_zero O) reduces to False, hence these two terms 
are convertible, that is identical. So, it should be possible to replace False 
with (not_zero O) in the conclusion, since they are the same term.

The tactic that does the job is the "change with" tactic. The invocation of 
"change with t" checks that the current goal is convertible with t, and in this 
case t becomes the new current goal. 

In our case, typing *)

change with (not_zero O);
 
(* we get the new goal (not_zero O). But we know, by H, that O=S n, 
hence by rewriting we get the the goal (not_zero (S n)) that reduces} to True,
whose proof is trivial: *)
>H // qed.

(* Using a similar technique you can always prove that different constructors of 
a same inductive type are distinct from each other; actually, this technique is 
also at the core of the "destruct" tactics of the previous chapter, in order to 
automatically close absurd cases. *)

(********************************** Inversion *********************************)
include "basics/logic.ma".

(* The only inductive type that really needs arguments is equality. In all other
cases you could conceptually get rid of them by adding, inside the type of 
constructors, the suitable equalities that would allow to turn arguments into 
parameters. 

Consider for instance our opp predicate of the introduction: *)

inductive bank : Type[0] ≝ 
  | east : bank
  | west : bank.

inductive opp : bank → bank → Prop ≝ 
  | east_west : opp east west
  | west_east : opp west east.

(* The predicate has two arguments, and since they are mixed up in the type of 
constructors we cannot express them as parameters. However, we could state it in 
the following alternative way: *)

inductive opp1 (b1,b2: bank): Prop ≝ 
  | east_west : b1 = east  → b2 = west → opp1 b1 b2
  | west_east : b1 = west  → b2 = east → opp1 b1 b2.

(* Or also, more elegantly, in terms of the opposite function *)

definition opposite ≝ λb. match b with [east ⇒ west | west ⇒ east].

inductive opp2 (b1,b2: bank): Prop ≝ 
  | opposite_to_opp2 : b1 = opposite b2 → opp2 b1 b2.

(* Suppose now to know (opp x west), where x:bank. From this hypothesis we 
should be able to conclude x = east, but this is slightly less trivial then one 
could expect. *)

lemma trivial_opp : ∀x. opp x west → x = east.
(* After introducing x and H:opp x west, one could be naturally tempted to 
proceed by cases on H, but this would lead us nowhere: in fact it would generate 
the following two subgoals: 

  G1: east=east 
  G2: west=east

The first one is trivial, but the second one is false and cannot be proved.
Also working by induction on $x$ (clearly, before introducing H) 
does not help, since we would get the goals

  G_1: opp east west → east=east
  G_2: opp west west → west=east

Again, the first goal is trivial, but proving that (opp west west) is absurd has 
about the same complexity of the original problem.
In fact, the best approach consists in "generalizing" the statement to something 
similar to lemma opp_to_opposite of the introduction, and then prove it as a 
corollary of the latter. *)
#x change with (opp x west → x=opposite west); generalize in match west;
#b * // qed. 

(* It is interesting to observe that we would not have the same problem with 
opp1 or opp2. For instance: *)

lemma trivial_opp1 : ∀x. opp1 x west → x = east.
#x #H cases H
(* applying cases analysis on H:opp1 x west, we obtain the two subgoals
  
  G_1: x=east → west=west → x=east
  G_2: x=west → west=east → x=east
  
The first one is trivial, and the second one is easily closed using descruct. *)
  [//|#H1 #H2 destruct (H2)] qed.

(* The point is that pattern matching is not powerful enough to discriminate the 
structure of arguments of inductive types. To this aim, however, you may exploit 
an alternative tactics called "Inversion". *)

(* Suppose to have in the local context an expression H:T t1 … tn, where T is 
some inductive type. Then, inversion applied to H derives for each possible 
constructor ci of (T t1 … tn), all the necessary conditions that should hold in 
order to have c_i:T t1 … tn.

For instance, let us consider again our trivial problem trivial_opp: *)

lemma trivial_opp2: ∀x. opp x west → x = east.
#x #H inversion H

(* the previous invocation to inversion results in the following subgoals:

  G1: x=east → west=west →x=east
  G2: x=west → west=east →x=east

How can we prove (opp t1 t2)? we have only two possibility: via east_west, that 
implies t1=east and t2=west, or via west_east, that implies t1=west and t2=west. 
Note also that G1 and G2 are precisely the same goals generated by case analysis 
on opp1. So we can vlose the goal in exactly the sane way: *)
  [//|#H1 #H2 destruct (H2)] qed.

(* Let us remark that invoking inversion on inductive types without arguments 
does not make any sense, and has no practical effect. *)

(* A final worning. Inversion generates equalities, and by convention it uses 
the standard leibniz quality defined basics/logic.ma. This is the reason why we
included this file at the beinning of this section, instead of working with our
local equality. *)

