Questo esempio segue questo tutorial

https://preliminary.istio.io/docs/tasks/traffic-management/egress/egress-gateway/

La **seconda** è quella copiata e modificata per l'esempio in questa cartella. Come vedrai, deployando questo va tutto (il traffico passa come dovrebbe dall'egress gateway, ma la connessione TLS è inizializzata e mantenuta dal POD client).

L'IP di pagopa è stato aggiunto manualmente a coredns (non è pubblicamente risolto).

Per fare un test dal container sleep usa: `curl --tlsv1.2 -vvv -d '<run>...</run>' http://gad.test.pagopa.gov.it/openspcoop2/proxy/PA/ -H "Content-Type: text
/xml" -sL` oppure `curl --tlsv1.2 -vvv -d '<run>...</run>' http://gad.test.pagopa.gov.it/openspcoop2/proxy/PA/ -H "Content-Type: text`