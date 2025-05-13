use validator::ValidateEmail;

#[derive(Debug)]
pub struct SubsriberEmail(String);

impl SubsriberEmail {
    pub fn parse(s: String) -> Result<SubsriberEmail, String> {
        if s.validate_email() {
            Ok(Self(s))
        } else {
            Err(format!("{} is not a valid subscriber email", s))
        }
    }
}

impl AsRef<str> for SubsriberEmail {
    fn as_ref(&self) -> &str {
        &self.0
    }
}

#[cfg(test)]
mod tests {
    use claims::assert_err;
    use fake::{Fake, faker::internet::en::SafeEmail};
    use rand::{SeedableRng, rngs::StdRng};

    use crate::domain::SubsriberEmail;

    #[test]
    fn empty_string_is_rejected() {
        let email = "".to_string();
        assert_err!(SubsriberEmail::parse(email));
    }

    #[test]
    fn email_missing_at_symbol_is_rejected() {
        let email = "ursuladomain.com".to_string();
        assert_err!(SubsriberEmail::parse(email));
    }

    #[test]
    fn email_missing_subject_is_rejected() {
        let email = "@domain.com".to_string();
        assert_err!(SubsriberEmail::parse(email));
    }

    #[derive(Debug, Clone)]
    struct ValidEmailFixture(pub String);

    impl quickcheck::Arbitrary for ValidEmailFixture {
        fn arbitrary(g: &mut quickcheck::Gen) -> Self {
            let mut rng = StdRng::seed_from_u64(u64::arbitrary(g));
            let email = SafeEmail().fake_with_rng(&mut rng);
            Self(email)
        }
    }

    #[quickcheck_macros::quickcheck]
    fn valid_email_are_paresed_successfully(valid_email: ValidEmailFixture) -> bool {
        SubsriberEmail::parse(valid_email.0).is_ok()
    }
}
