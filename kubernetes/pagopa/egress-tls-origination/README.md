Questo esempio segue questo tutorial

https://istio.io/docs/tasks/traffic-management/egress/egress-gateway-tls-origination/#perform-mutual-tls-origination-with-an-egress-gateway

La prima parte del tutorial basterebbe (se andasse) per ottenere un 403, quindi quello che vogliamo. La seconda parte fa anche la mutua autenticazione esponendo i certificati client (che ho già montato nell'egress gateway, quindi sono pronti all'uso), ma prima deve andare la prima parte.

L'IP di pagopa è stato aggiunto manualmente a coredns (non è pubblicamente risolto).

Per fare un test dal container sleep usa: `curl --tlsv1.2 -vvv -d '<run>...</run>' http://gad.test.pagopa.gov.it/openspcoop2/proxy/PA/ -H "Content-Type: text
/xml" -sL`