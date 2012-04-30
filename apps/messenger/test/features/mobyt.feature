# language: it

Funzionalità: Invio di sms con mobyt

    Scenario: restituzione parametri semplice

        Dato che lo username è "aaaa"
        E che la password è "bbbb"
        Quando invio un sms con i seguenti dati
            |   to          |     from          |   testo   |
            | +39123456789  |   mittente-prova  |   Ciao    |
        Allora il backend deve restituire i seguenti dati
            |   operation   |   TEXT                                |
            |   from        |   mittente-prova                      |
            |   data        |   Ciao                                |              
            |   id          |   aaaa                                |
            |   qty         |   a                                   |
            |   password    |                                       |
            |   ticket      |   3ad6bd5c1d3ea7b021b3f7ddad2398bd    |

    Scenario: invio messaggio con backend mobyt
    
        Dato che il backend è solo di tipo "mobyt"
        E che lo username è "aaaa"
        E che la password è "bbbb"
        E che il from è "mittente-prova"
        Quando invio un messaggio con messenger
        E faccio girare la coda dei messaggi
        Allora deve essere fatta una chiamata in "POST" all'url "http://smsweb.mobyt.it/sms-gw/sendsmart"        
