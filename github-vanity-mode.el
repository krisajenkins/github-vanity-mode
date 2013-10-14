;;; Code:
(require 'oauth2)
(require 'json)
(require 'cl-lib)
(require 's)
(require 'magit)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; Github Requests
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun github-vanity/fetch (uri)
  (assert (boundp 'github-token) t "Variable `github-token' must be set.")
  (with-current-buffer
      (oauth2-url-retrieve-synchronously github-token
					 (format "https://api.github.com%s" uri))
    (when (eq (url-http-parse-response) 200)
      (goto-char url-http-end-of-headers)
      (json-read))))

(defun github-vanity/fetch-repo (username reponame)
  (github-vanity/fetch (format "/repos/%s/%s" username reponame)))

(defun github-vanity/format-repo (repo-data)
  (format "W%dF%d"
	  (cdr (assoc 'watchers repo-data))
	  (cdr (assoc 'forks repo-data))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; Repo Discovery
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun github-vanity/repo-details-from-url (repo-url)
  "For the given REPO-URL, extracts a (username . reponame) pair."
  (if repo-url
      (let ((match (or (s-match "^git@github.com:\\(.*\\)/\\(.*?\\)\\(\\.git\\)?$" repo-url)
		       (s-match "^https://github.com/\\(.*\\)/\\(.*?\\)\\(\\.git\\)?$" repo-url))))
	(if match
	    (cons (elt match 1)
		  (elt match 2))))))

(ert-deftest github-vanity/repo-details-from-url-test ()
  (should (equal '("krisajenkins" . "github-vanity-mode")
		 (github-vanity/repo-details-from-url "git@github.com:krisajenkins/github-vanity-mode.git")))
  (should (equal '("krisajenkins" . "github-vanity-mode")
		 (github-vanity/repo-details-from-url "https://github.com/krisajenkins/github-vanity-mode.git"))))

(defun github-vanity/fetch-current-repo ()
  (destructuring-bind (username . reponame)
      (github-vanity/repo-details-from-url (magit-get "remote" "origin" "url"))
    (github-vanity/fetch-repo username reponame)))

(defun github-vanity/setup ()
  (interactive)
  (let ((current-repo (github-vanity/fetch-current-repo)))
    (when current-repo
      (github-vanity-mode t)
      (github-vanity/update-lighter
       (github-vanity/format-repo current-repo)))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; Minor Mode
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(defvar-local github-vanity-lighter nil)

(defun github-vanity/update-lighter (value)
  (setq github-vanity-lighter (format " %s" value))
  (force-mode-line-update))

;;;###autoload
(define-minor-mode github-vanity-mode
  "Show github stats for the current file's project."
  :global t
  :lighter github-vanity-lighter
  :after-hook (if github-vanity-mode
		   (github-vanity/setup)))

;;;###autoload
(defun turn-on-github-vanity-mode ()
  "Enable `github-vanity-mode' in the current buffer."
  (github-vanity-mode 1))

;;;###autoload
(defun turn-off-github-vanity-mode ()
  "Disable `github-vanity-mode' in the current buffer."
  (github-vanity-mode -1))

;;;###autoload
(define-globalized-minor-mode global-github-vanity-mode github-vanity-mode turn-on-github-vanity-mode)

(provide 'github-vanity-mode)
;;; github-vanity-mode.el ends here
