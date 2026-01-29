package main

import "github.com/openshift/library-go/pkg/crypto"

func main() {
	certString := `-----BEGIN CERTIFICATE-----
MIIDFzCCAf+gAwIBAgIUfsAS9AmliVATUxIiuCqK6s96+sowDQYJKoZIhvcNAQEL
BQAwGzEZMBcGA1UEAwwQT3BlblNoaWZ0IExhYiBDQTAeFw0yNjAxMjkxNjA4MjRa
Fw0yNjAyMjgxNjA4MjRaMBsxGTAXBgNVBAMMEE9wZW5TaGlmdCBMYWIgQ0EwggEi
MA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQCv8r4utYhqe/Yx/Qajv9S27vCy
nBN52I4OhXulWwoPLkvtkk14u2q+jbPMLyw/QraCENKFIBQnDNf0Xkw6r29B7N2i
TxlPvnPeTWhTUanxyPhzW5ltKiMReeAgEeDZkXonnUNh8eyPJyltQchI0AI/U/4k
mqWorpiyfrcv4XuFdxUFbvNxB+xNYfne5JUiYUZw+Dejkac8fpvbMucgiyuKGl2A
zKlpt9dzADM5zwnjusoaxLDVCOo1ZxtfBwJNnpKn+LhxGX98dl8l+OIObwbL1b4w
/7nONonUpeHakS9zwqeiUoF1GKtiuUHhdPnd/9lnz610quHCczD+ZstreiWVAgMB
AAGjUzBRMB0GA1UdDgQWBBQKmCVfvcUZGSa2Zm0ooBnuWPXqfDAfBgNVHSMEGDAW
gBQKmCVfvcUZGSa2Zm0ooBnuWPXqfDAPBgNVHRMBAf8EBTADAQH/MA0GCSqGSIb3
DQEBCwUAA4IBAQCCngxUk3T/HPjuthITFfJzedTrikBQ/etjJ9Ry9IGdaIoN9koo
FF3CSwDEnH6FJKWRy10Vs6GuzzPWCcaKMqOZEBmrWkqrvPPsAQ7EoD5d9RPs11u+
JZPZkveeSaJZs2ZzYjwGlQUJcqIoGDDVx75BalSj7rB3m5esZo5WkWwvxSq/3dad
/TFs0FnsOtGY8gRC9kTJfSzl02J/giyZgicrfNO5Yl32it1gVTr7gVcZAUAi/qLh
GjH/mzcgQ4W5W6GycUjYbbgtVE6r8oWjgBtZvoHpmiGDkeUsSf0mY9+VMZ7qdiBW
6pA9cRpOaiAJS2oY7x3EV20B+t5+nccOwOxA
-----END CERTIFICATE-----
`
	
	certs, err := crypto.CertsFromPEM([]byte(certString))
	if err != nil {
		panic(err)
	}

	for _, cert := range certs {
		println("Loaded certificate for:", cert.Subject.CommonName)
		println("IsCA:", cert.IsCA)
	}
}
