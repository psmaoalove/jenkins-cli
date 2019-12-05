package cmd

import (
	"github.com/jenkins-zh/jenkins-cli/client"
	"net/http"

	"github.com/jenkins-zh/jenkins-cli/app/i18n"

	"github.com/spf13/cobra"
)

// CASCReloadOption as the options of reload configuration as code
type CASCReloadOption struct {
	RoundTripper http.RoundTripper
}

var cascReloadOption CASCReloadOption

func init() {
	cascCmd.AddCommand(cascReloadCmd)
}

var cascReloadCmd = &cobra.Command{
	Use:   "reload",
	Short: i18n.T("Reload config through configuration-as-code"),
	Long:  i18n.T("Reload config through configuration-as-code"),
	RunE: func(cmd *cobra.Command, _ []string) error {
		jClient := &client.CASCManager{
			JenkinsCore: client.JenkinsCore{
				RoundTripper: cascReloadOption.RoundTripper,
			},
		}
		getCurrentJenkinsAndClient(&(jClient.JenkinsCore))
		return jClient.Reload()
	},
}