#!/bin/bash

INTERFACE="ens160"               # İzlenecek ağ arayüzü
THRESHOLD_MB=1                   # Eşik değeri (Mbit/s)

# Kuralın mevcut olup olmadığını kontrol eden fonksiyon
rule_exists() {
    iptables -L INPUT -v -n | grep -q "NEW" # Tüm yeni bağlantıları engelleyen kuralın olup olmadığını kontrol eder
}

# Kuralı ekleyen fonksiyon
add_rule() {
    if ! rule_exists; then
	    iptables -I INPUT 1 -m conntrack --ctstate NEW -p udp --dport 1:65535 -j REJECT
		iptables -I INPUT 2 -m conntrack --ctstate NEW -p udp --sport 1:65535 -j REJECT
		iptables -I INPUT 3 -m conntrack --ctstate NEW -p tcp --dport 1:65535 -j REJECT
		iptables -I INPUT 4 -m conntrack --ctstate NEW -p tcp --sport 1:65535 -j REJECT
		iptables -I INPUT 5 -m conntrack --ctstate NEW -s 0.0.0.0/0 -j REJECT
		iptables -I INPUT 6 -m conntrack --ctstate NEW -m length --length 1:65535 -j REJECT
		iptables -I INPUT 7 -m conntrack --ctstate NEW -m ttl --ttl-gt 0 -j REJECT
        echo "Sunucunuzun girisleri kesildi saldiri durdugunda acilacak"
    fi
}

# Kuralı kaldıran fonksiyon
remove_rule() {
    if rule_exists; then
        iptables -D INPUT -m conntrack --ctstate NEW -p udp --dport 1:65535 -j REJECT
		iptables -D INPUT -m conntrack --ctstate NEW -p udp --sport 1:65535 -j REJECT
		iptables -D INPUT -m conntrack --ctstate NEW -p tcp --dport 1:65535 -j REJECT
		iptables -D INPUT -m conntrack --ctstate NEW -p tcp --sport 1:65535 -j REJECT
		iptables -D INPUT -m conntrack --ctstate NEW -s 0.0.0.0/0 -j REJECT
		iptables -D INPUT -m conntrack --ctstate NEW -m length --length 1:65535 -j REJECT
		iptables -D INPUT -m conntrack --ctstate NEW -m ttl --ttl-gt 0 -j REJECT
        echo "Saldiri durdu ve girisler acildi tebrikler"
    fi
}

while true; do
    # ifstat'tan mevcut giriş hızını al
    OUTPUT=$(ifstat -i $INTERFACE 1 1 | tail -n 1)
    
    # Raw değerleri ayıklama
    RX_RATE=$(echo "$OUTPUT" | awk '{print $1}')
    
    # Debug bilgisi: Raw değer
    echo "Raw değer: $RX_RATE Kbyte/s"

    # Kbyte/s cinsinden hız
    CURRENT_RATE_MB=$(echo "$RX_RATE * 8 / 1024" | bc -l)
    
    # Debug bilgisi: Mevcut hız
    echo "Mevcut hız: $CURRENT_RATE_MB Mbit/s (Eşik: $THRESHOLD_MB Mbit/s)"

    # Eşik değerini kontrol et
    if (( $(echo "$CURRENT_RATE_MB >= $THRESHOLD_MB" | bc -l) )); then
        echo "Eşik değeri aşıldı. Hız: $CURRENT_RATE_MB Mbit/s"
        # Eşik değeri aşıldığında kuralı uygula
        add_rule
    else
        echo "Eşik değeri aşılmadı. Hız: $CURRENT_RATE_MB Mbit/s"
        # Eşik değeri aşılmadığında kuralı kaldır
        remove_rule
    fi

    # Belirli bir süre bekle (örneğin 1 saniye)
    sleep 1
done
