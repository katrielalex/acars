theory sACARS
begin

builtins: diffie-hellman, signing, asymmetric-encryption

section{* sACARS *}

/*
 * Protocol:	Secure ACARS
 * Modeler: 	Katriel Cohn-Gordon
 * Date: 	January 2016
 * Source:	secure ACARS patent
 * Property: 	eCK?
 *
 * Status: 	In Development
 */

functions: H/1

/* Protocol rules */

/* Generate long-term keypair */
rule generate_ltk:
  let pkA = 'g'^~ea 
  in
  [ Fr(~ea) ] 
  --[ RegKey($A) ]->
  [ !Ltk( $A, ~ea ), !Pk( $A, pkA ), Out( pkA ) ]

rule Airplane_1:
     let m1 = <$A, $B, 'time'>
         signature = sign{m1}~ea
     in
     [ !Ltk( $A, ~ea) ]
     -->
     [ Out(<m1, signature>),
       St_A_1(~ea, m1, signature)
     ]

rule Ground_1:
     let m1 = <$A, $B, 'time'>
         Z = pkA^~eb
         Km = H(<Z, '0', signature, ~R>)
         Ke = H(<Z, '1', Km, $A, $B>)
         Data = <$B, $A, ~R, 'Count', 'g'^~eb>
         MAC = H(<Km, $B, $A, 'Count', Data, signature>)
         
         m2 = <Data, MAC>
     in
     [ In(<m1, signature>),
       Fr(~R),
       !Ltk($A, ~ea),
       !Pk($A, pkA),
       !Ltk($B, ~eb)
     ]
     --[ Accept(Ke) ]->
     [ Out(m2) ]

rule Airplane_2:
     let m2 = <<$B, $A, R, 'Count', pkB>, MAC_received>
         Z = pkB^~ea
         Km = H(<Z, '0', signature, R>)
         Ke = H(<Z, '1', Km, $A, $B>)
     in
     [ In(m2),
       St_A_1(~ea, m1, signature),
       !Pk($B, pkB)
     ]
     --[ Accept(Ke) ]->
     [  ]

/* Key Reveals for the eCK model */
/*
rule Sessk_reveal: 
   [ !Sessk(~s, k) ] --[ RevealSessk(~s) ]-> [ Out(k) ]

rule Ltk_reveal:
   [ !Ltk($A, ea) ] --[ RevealLtk($A) ]-> [ Out(ea) ]

rule Ephk_reveal:
   [ !Ephk(~s, ~ek) ] --[ RevealEphk(~s) ]-> [ Out(~ek) ]
*/

/* Security properties */
lemma Keys_Secret:
      "All Ke #j. Accept(Ke) @ j ==> not(Ex #k. K(Ke) @ k)"

/*
lemma eCK_same_key:
  " // If every agent registered at most one public key
  (All A #i #j. RegKey(A)@i & RegKey(A)@j ==> (#i = #j))
  ==> // then matching sessions accept the same key
  (not (Ex #i1 #i2 #i3 #i4 s ss k kk A B minfo .
              Accept(s, A, B, k ) @ i1
	    & Accept(ss, B, A, kk) @ i2
	    & Sid(s, minfo) @ i3
	    & Match(ss, minfo) @i4
	    & not( k = kk )
  ) )"
*/

lemma eCK_key_secrecy:
  /* 
   * The property specification is a (logically equivalent) simplified
   * version of the one in the original eCK (ProvSec) paper:
   *
   * If there exists a test session whose key k is known to the
   * Adversary with some session-id, then...
   */
  "(All #i1 #i2 #i3 test A B k sent recvd role.
    Accept(test, k) @ i1 & K( k ) @ i2 & Sid(test, < A, B, sent, recvd, role> ) @ i3
    ==> ( 
    /* ... the test session must be "not clean".
     * test is not clean if one of the following has happened:
     */
    /* 1. The adversary has revealed the session key of the test session. */
      (Ex #i3. RevealSessk( test ) @ i3 )
    
    /* 2. The adversary has revealed both the longterm key of A and the
          ephemeral key of the test session */
    |  (Ex #i5 #i6. RevealLtk  ( A ) @ i5  & RevealEphk ( test  ) @ i6 )

    /* 3. There is a matching session and */
    | (Ex matchingSession #i3 matchingRole.
           (   Sid ( matchingSession, < B, A, recvd, sent, matchingRole > ) @ i3 
             & not ( matchingRole = role ) )
	   & (
             /* (a) the adversary has revealed the session key of the matching session, or */
	       (Ex #i5. RevealSessk( matchingSession ) @ i5 )

             /* (b) the adversary has revealed the longterm key of B and the ephemeral
                    key of the matching session. */
             | (Ex #i5 #i6. RevealLtk  ( B ) @ i5  & RevealEphk ( matchingSession ) @ i6 )
	   )
      )
    /* 4. There is no matching session and */
    | ( ( not(Ex matchingSession #i3 matchingRole.
           ( Sid ( matchingSession, < B, A, recvd, sent, matchingRole > ) @ i3 
             & not ( matchingRole = role ) )))

           /* the adversary has revealed the longterm key of B. */
	   & ( (Ex #i5. RevealLtk (B) @ i5 )
	   )
      )
    )
  )"

end
