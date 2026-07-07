; /var/named/db.cercueil.fun - zone publique cercueil.fun sur le DNS maitre
; Transcrit depuis la capture de la documentation
$TTL 86400
@ IN SOA ns1.cercueil.fun. admin.cercueil.fun. (
                2026051503 ; Serial (AAAAMMJJ + increment, declenche le transfert vers l'esclave)
                1d         ; Refresh
                3h         ; Retry
                3d         ; Expire
                3h )       ; Minimum TTL (cache negatif)

@       IN NS   ns1.cercueil.fun.
@       IN NS   ns2.cercueil.fun.
ns1     IN A    212.83.153.84
ns2     IN A    212.83.153.84
