module Spider::CommandLine

    class CertCommand < CmdParse::Command


        def initialize
            super( 'cert', true, true )
            @short_desc = _("Manage certificates")
    #        @description = _("")
       
            # start
            generate = CmdParse::Command.new( 'generate', false )
            generate.short_desc = _("Generate new X.509")
            generate.options = CmdParse::OptionParserWrapper.new do |opt|
                opt.on("--path path", _("Where to generate the certificate"), "-p") { |path|
                    @path = path
                }
                opt.on("--org label", _("Name of the organization to generate the certificate for"), "-o"){ |org|
                    @org = org
                }
            end
            generate.set_execution_block do |args|
                require 'spiderfw'
                Spider.init_base
                require 'openssl'
                @path ||= Spider.paths[:certs]
                @org ||= 'default'
                path = @path+'/'+@org
                orgs = Spider.conf.get('orgs')
                o = orgs[@org] if orgs
                raise _("You have to configure the organization '#{@org}' to generate a certificate") unless o
                raise _("You have to set the organization name for '#{@org}' in configuration") unless o['name']
                raise _("You have to set the organization country code for '#{@org}' in configuration") unless o['country_code']
                raise _("You have to set the organization state for '#{@org}' in configuration") unless o['state']
                raise _("You have to set the organization city for '#{@org}' in configuration") unless o['city']
                raise _("You have to set the organization common name for '#{@org}' in configuration") unless o['common_name']
                raise _("You have to set the organization email address for '#{@org}' in configuration") unless o['email']
                id = "/C=#{o['country_code']}/ST=#{o['state']}/L=#{o['city']}"
                id += "/OU=#{o['organizational_unit']}" if o['organizational_unit']
                id += "/CN=#{o['common_name']}/emailAddress=#{o['email']}"
                FileUtils.mkpath(path+'/private')
                key = OpenSSL::PKey::RSA.generate(4096)
                pub = key.public_key
                # O => organization (Example company)
                # OU => organizational unit (Test department)
                # CN => common name (my company name)
                # /C=US/ST=Florida/L=Miami/O=Waitingf/OU=Poopstat/CN=waitingf.org/emailAddress=bkerley@brycekerley.net
                ca = OpenSSL::X509::Name.parse(id)
                cert = OpenSSL::X509::Certificate.new
                cert.version = 2
                cert.serial = 1
                cert.subject = ca
                cert.issuer = ca
                cert.public_key = pub
                cert.not_before = Time.now
                cert.not_after = Time.now + (60*60*24*356*3)
                cert.sign(key, OpenSSL::Digest::SHA1.new)
                File.open(path+"/public.pem", "w"){ |f| f.write pub.to_pem }
                File.open(path+"/private/key.pem", "w") { |f| f.write key.to_pem }
                File.open(path+"/cert.pem", "w") { |f| f.write cert.to_pem }
            end
            self.add_command( generate )

            # stop


        end

    end



    # Documentation:
    # 
    # require "openssl"
    # require "test/unit"
    # 
    # module OpenSSL::TestUtils
    #   TEST_KEY_RSA1024 = OpenSSL::PKey::RSA.new <<-_end_of_pem_
    # -----BEGIN RSA PRIVATE KEY-----
    # MIICXgIBAAKBgQDLwsSw1ECnPtT+PkOgHhcGA71nwC2/nL85VBGnRqDxOqjVh7Cx
    # aKPERYHsk4BPCkE3brtThPWc9kjHEQQ7uf9Y1rbCz0layNqHyywQEVLFmp1cpIt/
    # Q3geLv8ZD9pihowKJDyMDiN6ArYUmZczvW4976MU3+l54E6lF/JfFEU5hwIDAQAB
    # AoGBAKSl/MQarye1yOysqX6P8fDFQt68VvtXkNmlSiKOGuzyho0M+UVSFcs6k1L0
    # maDE25AMZUiGzuWHyaU55d7RXDgeskDMakD1v6ZejYtxJkSXbETOTLDwUWTn618T
    # gnb17tU1jktUtU67xK/08i/XodlgnQhs6VoHTuCh3Hu77O6RAkEA7+gxqBuZR572
    # 74/akiW/SuXm0SXPEviyO1MuSRwtI87B02D0qgV8D1UHRm4AhMnJ8MCs1809kMQE
    # JiQUCrp9mQJBANlt2ngBO14us6NnhuAseFDTBzCHXwUUu1YKHpMMmxpnGqaldGgX
    # sOZB3lgJsT9VlGf3YGYdkLTNVbogQKlKpB8CQQDiSwkb4vyQfDe8/NpU5Not0fII
    # 8jsDUCb+opWUTMmfbxWRR3FBNu8wnym/m19N4fFj8LqYzHX4KY0oVPu6qvJxAkEA
    # wa5snNekFcqONLIE4G5cosrIrb74sqL8GbGb+KuTAprzj5z1K8Bm0UW9lTjVDjDi
    # qRYgZfZSL+x1P/54+xTFSwJAY1FxA/N3QPCXCjPh5YqFxAMQs2VVYTfg+t0MEcJD
    # dPMQD5JX6g5HKnHFg2mZtoXQrWmJSn7p8GJK8yNTopEErA==
    # -----END RSA PRIVATE KEY-----
    #   _end_of_pem_
    # 
    #   TEST_KEY_RSA2048 = OpenSSL::PKey::RSA.new <<-_end_of_pem_
    # -----BEGIN RSA PRIVATE KEY-----
    # MIIEpAIBAAKCAQEAuV9ht9J7k4NBs38jOXvvTKY9gW8nLICSno5EETR1cuF7i4pN
    # s9I1QJGAFAX0BEO4KbzXmuOvfCpD3CU+Slp1enenfzq/t/e/1IRW0wkJUJUFQign
    # 4CtrkJL+P07yx18UjyPlBXb81ApEmAB5mrJVSrWmqbjs07JbuS4QQGGXLc+Su96D
    # kYKmSNVjBiLxVVSpyZfAY3hD37d60uG+X8xdW5v68JkRFIhdGlb6JL8fllf/A/bl
    # NwdJOhVr9mESHhwGjwfSeTDPfd8ZLE027E5lyAVX9KZYcU00mOX+fdxOSnGqS/8J
    # DRh0EPHDL15RcJjV2J6vZjPb0rOYGDoMcH+94wIDAQABAoIBAAzsamqfYQAqwXTb
    # I0CJtGg6msUgU7HVkOM+9d3hM2L791oGHV6xBAdpXW2H8LgvZHJ8eOeSghR8+dgq
    # PIqAffo4x1Oma+FOg3A0fb0evyiACyrOk+EcBdbBeLo/LcvahBtqnDfiUMQTpy6V
    # seSoFCwuN91TSCeGIsDpRjbG1vxZgtx+uI+oH5+ytqJOmfCksRDCkMglGkzyfcl0
    # Xc5CUhIJ0my53xijEUQl19rtWdMnNnnkdbG8PT3LZlOta5Do86BElzUYka0C6dUc
    # VsBDQ0Nup0P6rEQgy7tephHoRlUGTYamsajGJaAo1F3IQVIrRSuagi7+YpSpCqsW
    # wORqorkCgYEA7RdX6MDVrbw7LePnhyuaqTiMK+055/R1TqhB1JvvxJ1CXk2rDL6G
    # 0TLHQ7oGofd5LYiemg4ZVtWdJe43BPZlVgT6lvL/iGo8JnrncB9Da6L7nrq/+Rvj
    # XGjf1qODCK+LmreZWEsaLPURIoR/Ewwxb9J2zd0CaMjeTwafJo1CZvcCgYEAyCgb
    # aqoWvUecX8VvARfuA593Lsi50t4MEArnOXXcd1RnXoZWhbx5rgO8/ATKfXr0BK/n
    # h2GF9PfKzHFm/4V6e82OL7gu/kLy2u9bXN74vOvWFL5NOrOKPM7Kg+9I131kNYOw
    # Ivnr/VtHE5s0dY7JChYWE1F3vArrOw3T00a4CXUCgYEA0SqY+dS2LvIzW4cHCe9k
    # IQqsT0yYm5TFsUEr4sA3xcPfe4cV8sZb9k/QEGYb1+SWWZ+AHPV3UW5fl8kTbSNb
    # v4ng8i8rVVQ0ANbJO9e5CUrepein2MPL0AkOATR8M7t7dGGpvYV0cFk8ZrFx0oId
    # U0PgYDotF/iueBWlbsOM430CgYEAqYI95dFyPI5/AiSkY5queeb8+mQH62sdcCCr
    # vd/w/CZA/K5sbAo4SoTj8dLk4evU6HtIa0DOP63y071eaxvRpTNqLUOgmLh+D6gS
    # Cc7TfLuFrD+WDBatBd5jZ+SoHccVrLR/4L8jeodo5FPW05A+9gnKXEXsTxY4LOUC
    # 9bS4e1kCgYAqVXZh63JsMwoaxCYmQ66eJojKa47VNrOeIZDZvd2BPVf30glBOT41
    # gBoDG3WMPZoQj9pb7uMcrnvs4APj2FIhMU8U15LcPAj59cD6S6rWnAxO8NFK7HQG
    # 4Jxg3JNNf8ErQoCHb1B3oVdXJkmbJkARoDpBKmTCgKtP8ADYLmVPQw==
    # -----END RSA PRIVATE KEY-----
    #   _end_of_pem_
    # 
    #   TEST_KEY_DSA256 = OpenSSL::PKey::DSA.new <<-_end_of_pem_
    # -----BEGIN DSA PRIVATE KEY-----
    # MIH3AgEAAkEAhk2libbY2a8y2Pt21+YPYGZeW6wzaW2yfj5oiClXro9XMR7XWLkE
    # 9B7XxLNFCS2gmCCdMsMW1HulaHtLFQmB2wIVAM43JZrcgpu6ajZ01VkLc93gu/Ed
    # AkAOhujZrrKV5CzBKutKLb0GVyVWmdC7InoNSMZEeGU72rT96IjM59YzoqmD0pGM
    # 3I1o4cGqg1D1DfM1rQlnN1eSAkBq6xXfEDwJ1mLNxF6q8Zm/ugFYWR5xcX/3wFiT
    # b4+EjHP/DbNh9Vm5wcfnDBJ1zKvrMEf2xqngYdrV/3CiGJeKAhRvL57QvJZcQGvn
    # ISNX5cMzFHRW3Q==
    # -----END DSA PRIVATE KEY-----
    #   _end_of_pem_
    # 
    #   TEST_KEY_DSA512 = OpenSSL::PKey::DSA.new <<-_end_of_pem_
    # -----BEGIN DSA PRIVATE KEY-----
    # MIH4AgEAAkEA5lB4GvEwjrsMlGDqGsxrbqeFRh6o9OWt6FgTYiEEHaOYhkIxv0Ok
    # RZPDNwOG997mDjBnvDJ1i56OmS3MbTnovwIVAJgub/aDrSDB4DZGH7UyarcaGy6D
    # AkB9HdFw/3td8K4l1FZHv7TCZeJ3ZLb7dF3TWoGUP003RCqoji3/lHdKoVdTQNuR
    # S/m6DlCwhjRjiQ/lBRgCLCcaAkEAjN891JBjzpMj4bWgsACmMggFf57DS0Ti+5++
    # Q1VB8qkJN7rA7/2HrCR3gTsWNb1YhAsnFsoeRscC+LxXoXi9OAIUBG98h4tilg6S
    # 55jreJD3Se3slps=
    # -----END DSA PRIVATE KEY-----
    #   _end_of_pem_
    # 
    #   module_function
    # 
    #   def issue_cert(dn, key, serial, not_before, not_after, extensions,
    #                  issuer, issuer_key, digest)
    #     cert = OpenSSL::X509::Certificate.new
    #     issuer = cert unless issuer
    #     issuer_key = key unless issuer_key
    #     cert.version = 2
    #     cert.serial = serial
    #     cert.subject = dn
    #     cert.issuer = issuer.subject
    #     cert.public_key = key.public_key
    #     cert.not_before = not_before
    #     cert.not_after = not_after
    #     ef = OpenSSL::X509::ExtensionFactory.new
    #     ef.subject_certificate = cert
    #     ef.issuer_certificate = issuer
    #     extensions.each{|oid, value, critical|
    #       cert.add_extension(ef.create_extension(oid, value, critical))
    #     }
    #     cert.sign(issuer_key, digest)
    #     cert
    #   end
    # 
    #   def issue_crl(revoke_info, serial, lastup, nextup, extensions, 
    #                 issuer, issuer_key, digest)
    #     crl = OpenSSL::X509::CRL.new
    #     crl.issuer = issuer.subject
    #     crl.version = 1
    #     crl.last_update = lastup
    #     crl.next_update = nextup
    #     revoke_info.each{|serial, time, reason_code|
    #       revoked = OpenSSL::X509::Revoked.new
    #       revoked.serial = serial
    #       revoked.time = time
    #       enum = OpenSSL::ASN1::Enumerated(reason_code)
    #       ext = OpenSSL::X509::Extension.new("CRLReason", enum)
    #       revoked.add_extension(ext)
    #       crl.add_revoked(revoked)
    #     }
    #     ef = OpenSSL::X509::ExtensionFactory.new
    #     ef.issuer_certificate = issuer
    #     ef.crl = crl
    #     crlnum = OpenSSL::ASN1::Integer(serial)
    #     crl.add_extension(OpenSSL::X509::Extension.new("crlNumber", crlnum))
    #     extensions.each{|oid, value, critical|
    #       crl.add_extension(ef.create_extension(oid, value, critical))
    #     }
    #     crl.sign(issuer_key, digest)
    #     crl
    #   end
    # 
    #   def get_subject_key_id(cert)
    #     asn1_cert = OpenSSL::ASN1.decode(cert)
    #     tbscert   = asn1_cert.value[0]
    #     pkinfo    = tbscert.value[6]
    #     publickey = pkinfo.value[1]
    #     pkvalue   = publickey.value
    #     OpenSSL::Digest::SHA1.hexdigest(pkvalue).scan(/../).join(":").upcase
    #   end
    # end
    # 
    # 
    # # Test
    # 
    # 
    # if defined?(OpenSSL)
    # 
    # class OpenSSL::TestX509CRL < Test::Unit::TestCase
    #   def setup
    #     @rsa1024 = OpenSSL::TestUtils::TEST_KEY_RSA1024
    #     @rsa2048 = OpenSSL::TestUtils::TEST_KEY_RSA2048
    #     @dsa256  = OpenSSL::TestUtils::TEST_KEY_DSA256
    #     @dsa512  = OpenSSL::TestUtils::TEST_KEY_DSA512
    #     @ca = OpenSSL::X509::Name.parse("/DC=org/DC=ruby-lang/CN=CA")
    #     @ee1 = OpenSSL::X509::Name.parse("/DC=org/DC=ruby-lang/CN=EE1")
    #     @ee2 = OpenSSL::X509::Name.parse("/DC=org/DC=ruby-lang/CN=EE2")
    #   end
    # 
    #   def teardown
    #   end
    # 
    #   def issue_crl(*args)
    #     OpenSSL::TestUtils.issue_crl(*args)
    #   end
    # 
    #   def issue_cert(*args)
    #     OpenSSL::TestUtils.issue_cert(*args)
    #   end
    # 
    #   def test_basic
    #     now = Time.at(Time.now.to_i)
    # 
    #     cert = issue_cert(@ca, @rsa2048, 1, now, now+3600, [],
    #                       nil, nil, OpenSSL::Digest::SHA1.new)
    #     crl = issue_crl([], 1, now, now+1600, [],
    #                     cert, @rsa2048, OpenSSL::Digest::SHA1.new)
    #     assert_equal(1, crl.version)
    #     assert_equal(cert.issuer.to_der, crl.issuer.to_der)
    #     assert_equal(now, crl.last_update)
    #     assert_equal(now+1600, crl.next_update)
    # 
    #     crl = OpenSSL::X509::CRL.new(crl.to_der)
    #     assert_equal(1, crl.version)
    #     assert_equal(cert.issuer.to_der, crl.issuer.to_der)
    #     assert_equal(now, crl.last_update)
    #     assert_equal(now+1600, crl.next_update)
    #   end
    # 
    #   def test_revoked
    # 
    #     # CRLReason ::= ENUMERATED {
    #     #      unspecified             (0),
    #     #      keyCompromise           (1),
    #     #      cACompromise            (2),
    #     #      affiliationChanged      (3),
    #     #      superseded              (4),
    #     #      cessationOfOperation    (5),
    #     #      certificateHold         (6),
    #     #      removeFromCRL           (8),
    #     #      privilegeWithdrawn      (9),
    #     #      aACompromise           (10) }
    # 
    #     now = Time.at(Time.now.to_i)
    #     revoke_info = [
    #       [1, Time.at(0),          1],
    #       [2, Time.at(0x7fffffff), 2],
    #       [3, now,                 3],
    #       [4, now,                 4],
    #       [5, now,                 5],
    #     ]
    #     cert = issue_cert(@ca, @rsa2048, 1, Time.now, Time.now+3600, [],
    #                       nil, nil, OpenSSL::Digest::SHA1.new)
    #     crl = issue_crl(revoke_info, 1, Time.now, Time.now+1600, [],
    #                     cert, @rsa2048, OpenSSL::Digest::SHA1.new)
    #     revoked = crl.revoked
    #     assert_equal(5, revoked.size)
    #     assert_equal(1, revoked[0].serial)
    #     assert_equal(2, revoked[1].serial)
    #     assert_equal(3, revoked[2].serial)
    #     assert_equal(4, revoked[3].serial)
    #     assert_equal(5, revoked[4].serial)
    # 
    #     assert_equal(Time.at(0), revoked[0].time)
    #     assert_equal(Time.at(0x7fffffff), revoked[1].time)
    #     assert_equal(now, revoked[2].time)
    #     assert_equal(now, revoked[3].time)
    #     assert_equal(now, revoked[4].time)
    # 
    #     assert_equal("CRLReason", revoked[0].extensions[0].oid)
    #     assert_equal("CRLReason", revoked[1].extensions[0].oid)
    #     assert_equal("CRLReason", revoked[2].extensions[0].oid)
    #     assert_equal("CRLReason", revoked[3].extensions[0].oid)
    #     assert_equal("CRLReason", revoked[4].extensions[0].oid)
    # 
    #     assert_equal("Key Compromise", revoked[0].extensions[0].value)
    #     assert_equal("CA Compromise", revoked[1].extensions[0].value)
    #     assert_equal("Affiliation Changed", revoked[2].extensions[0].value)
    #     assert_equal("Superseded", revoked[3].extensions[0].value)
    #     assert_equal("Cessation Of Operation", revoked[4].extensions[0].value)
    # 
    #     assert_equal(false, revoked[0].extensions[0].critical?)
    #     assert_equal(false, revoked[1].extensions[0].critical?)
    #     assert_equal(false, revoked[2].extensions[0].critical?)
    #     assert_equal(false, revoked[3].extensions[0].critical?)
    #     assert_equal(false, revoked[4].extensions[0].critical?)
    # 
    #     crl = OpenSSL::X509::CRL.new(crl.to_der)
    #     assert_equal("Key Compromise", revoked[0].extensions[0].value)
    #     assert_equal("CA Compromise", revoked[1].extensions[0].value)
    #     assert_equal("Affiliation Changed", revoked[2].extensions[0].value)
    #     assert_equal("Superseded", revoked[3].extensions[0].value)
    #     assert_equal("Cessation Of Operation", revoked[4].extensions[0].value)
    # 
    #     revoke_info = (1..1000).collect{|i| [i, now, 0] }
    #     crl = issue_crl(revoke_info, 1, Time.now, Time.now+1600, [],
    #                     cert, @rsa2048, OpenSSL::Digest::SHA1.new)
    #     revoked = crl.revoked
    #     assert_equal(1000, revoked.size)
    #     assert_equal(1, revoked[0].serial)
    #     assert_equal(1000, revoked[999].serial)
    #   end
    # 
    #   def test_extension
    #     cert_exts = [
    #       ["basicConstraints", "CA:TRUE", true],
    #       ["subjectKeyIdentifier", "hash", false], 
    #       ["authorityKeyIdentifier", "keyid:always", false], 
    #       ["subjectAltName", "email:xyzzy@ruby-lang.org", false],
    #       ["keyUsage", "cRLSign, keyCertSign", true],
    #     ]
    #     crl_exts = [
    #       ["authorityKeyIdentifier", "keyid:always", false], 
    #       ["issuerAltName", "issuer:copy", false],
    #     ]
    #     
    #     cert = issue_cert(@ca, @rsa2048, 1, Time.now, Time.now+3600, cert_exts,
    #                       nil, nil, OpenSSL::Digest::SHA1.new)
    #     crl = issue_crl([], 1, Time.now, Time.now+1600, crl_exts,
    #                     cert, @rsa2048, OpenSSL::Digest::SHA1.new)
    #     exts = crl.extensions
    #     assert_equal(3, exts.size)
    #     assert_equal("1", exts[0].value)
    #     assert_equal("crlNumber", exts[0].oid)
    #     assert_equal(false, exts[0].critical?)
    # 
    #     assert_equal("authorityKeyIdentifier", exts[1].oid)
    #     keyid = OpenSSL::TestUtils.get_subject_key_id(cert)
    #     assert_match(/^keyid:#{keyid}/, exts[1].value)
    #     assert_equal(false, exts[1].critical?)
    # 
    #     assert_equal("issuerAltName", exts[2].oid)
    #     assert_equal("email:xyzzy@ruby-lang.org", exts[2].value)
    #     assert_equal(false, exts[2].critical?)
    # 
    #     crl = OpenSSL::X509::CRL.new(crl.to_der)
    #     exts = crl.extensions
    #     assert_equal(3, exts.size)
    #     assert_equal("1", exts[0].value)
    #     assert_equal("crlNumber", exts[0].oid)
    #     assert_equal(false, exts[0].critical?)
    # 
    #     assert_equal("authorityKeyIdentifier", exts[1].oid)
    #     keyid = OpenSSL::TestUtils.get_subject_key_id(cert)
    #     assert_match(/^keyid:#{keyid}/, exts[1].value)
    #     assert_equal(false, exts[1].critical?)
    # 
    #     assert_equal("issuerAltName", exts[2].oid)
    #     assert_equal("email:xyzzy@ruby-lang.org", exts[2].value)
    #     assert_equal(false, exts[2].critical?)
    #   end
    # 
    #   def test_crlnumber
    #     cert = issue_cert(@ca, @rsa2048, 1, Time.now, Time.now+3600, [],
    #                       nil, nil, OpenSSL::Digest::SHA1.new)
    #     crl = issue_crl([], 1, Time.now, Time.now+1600, [],
    #                     cert, @rsa2048, OpenSSL::Digest::SHA1.new)
    #     assert_match(1.to_s, crl.extensions[0].value)
    #     assert_match(/X509v3 CRL Number:\s+#{1}/m, crl.to_text)
    # 
    #     crl = issue_crl([], 2**32, Time.now, Time.now+1600, [],
    #                     cert, @rsa2048, OpenSSL::Digest::SHA1.new)
    #     assert_match((2**32).to_s, crl.extensions[0].value)
    #     assert_match(/X509v3 CRL Number:\s+#{2**32}/m, crl.to_text)
    # 
    #     crl = issue_crl([], 2**100, Time.now, Time.now+1600, [],
    #                     cert, @rsa2048, OpenSSL::Digest::SHA1.new)
    #     assert_match(/X509v3 CRL Number:\s+#{2**100}/m, crl.to_text)
    #     assert_match((2**100).to_s, crl.extensions[0].value)
    #   end
    # 
    #   def test_sign_and_verify
    #     cert = issue_cert(@ca, @rsa2048, 1, Time.now, Time.now+3600, [],
    #                       nil, nil, OpenSSL::Digest::SHA1.new)
    #     crl = issue_crl([], 1, Time.now, Time.now+1600, [],
    #                     cert, @rsa2048, OpenSSL::Digest::SHA1.new)
    #     assert_equal(false, crl.verify(@rsa1024))
    #     assert_equal(true,  crl.verify(@rsa2048))
    #     assert_equal(false, crl.verify(@dsa256))
    #     assert_equal(false, crl.verify(@dsa512))
    #     crl.version = 0
    #     assert_equal(false, crl.verify(@rsa2048))
    # 
    #     cert = issue_cert(@ca, @dsa512, 1, Time.now, Time.now+3600, [],
    #                       nil, nil, OpenSSL::Digest::DSS1.new)
    #     crl = issue_crl([], 1, Time.now, Time.now+1600, [],
    #                     cert, @dsa512, OpenSSL::Digest::DSS1.new)
    #     assert_equal(false, crl.verify(@rsa1024))
    #     assert_equal(false, crl.verify(@rsa2048))
    #     assert_equal(false, crl.verify(@dsa256))
    #     assert_equal(true,  crl.verify(@dsa512))
    #     crl.version = 0
    #     assert_equal(false, crl.verify(@dsa512))
    #   end
    # end
    # 
    # end
    # 
    # 
    # 
    # 

end